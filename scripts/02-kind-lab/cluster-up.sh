#!/usr/bin/env bash
#
# cluster-up.sh - kind ile tek kullanimlik bir Kubernetes cluster'i kurar.
#
# Kurulanlar:
#   * 1 control-plane + N worker node (hepsi docker konteyneri)
#   * Yerel imaj deposu (registry:2) - 'docker push localhost:5001/app:dev' ile
#     itilen imajlar cluster icinden dogrudan cekilebilir; 'kind load' gerekmez
#   * Istege bagli ingress-nginx (--ingress 1)
#
# Kurulum suresi: node imaji onbellekteyse ~40 saniye.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh disable=SC1091
source "${REPO_ROOT}/lib/common.sh"
enable_error_trap

# --- Varsayilanlar ---------------------------------------------------------
NAME="lab"
WORKERS=2
K8S_IMAGE=""
WITH_REGISTRY=1
REG_PORT=5001
REG_NAME="kind-registry"
WITH_INGRESS=0
HTTP_PORT=8080
HTTPS_PORT=8443
RECREATE=0

INGRESS_MANIFEST="https://raw.githubusercontent.com/kubernetes-sigs/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml"

TMP_FILES=()
cleanup() {
  local f
  for f in "${TMP_FILES[@]}"; do
    if [[ -n $f && -f $f ]]; then
      rm -f "$f"
    fi
  done
  return 0
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
Kullanim: cluster-up.sh [SECENEKLER]

Secenekler:
  --name <ad>            Cluster adi (varsayilan: lab)
  --workers <n>          Worker node sayisi (varsayilan: 2, 0 = tek node)
  --k8s <imaj|surum>     Node imaji, ornek: v1.31.2 veya kindest/node:v1.31.2
  --registry <0|1>       Yerel imaj deposu kurulsun mu (varsayilan: 1)
  --registry-port <p>    Imaj deposu portu (varsayilan: 5001)
  --ingress <0|1>        ingress-nginx kurulsun mu (varsayilan: 0)
  --http-port <p>        Ingress icin host HTTP portu (varsayilan: 8080)
  --https-port <p>       Ingress icin host HTTPS portu (varsayilan: 8443)
  --force                Ayni adda cluster varsa silip yeniden kurar
  --yes                  Onay sorularini atlar
  --no-color             Renkli ciktiyi kapatir
  -h, --help             Bu yardimi gosterir

Ornekler:
  ./cluster-up.sh
  ./cluster-up.sh --name test --workers 3
  ./cluster-up.sh --workers 0 --ingress 1
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      NAME="$2"
      shift 2
      ;;
    --workers)
      WORKERS="$2"
      shift 2
      ;;
    --k8s)
      K8S_IMAGE="$2"
      shift 2
      ;;
    --registry)
      WITH_REGISTRY="$2"
      shift 2
      ;;
    --registry-port)
      REG_PORT="$2"
      shift 2
      ;;
    --ingress)
      WITH_INGRESS="$2"
      shift 2
      ;;
    --http-port)
      HTTP_PORT="$2"
      shift 2
      ;;
    --https-port)
      HTTPS_PORT="$2"
      shift 2
      ;;
    --force)
      RECREATE=1
      shift
      ;;
    --yes)
      ASSUME_YES=1
      shift
      ;;
    --no-color)
      disable_colors
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "Bilinmeyen secenek: $1 (yardim icin --help)" ;;
  esac
done

# 'v1.31.2' gibi kisa yazim da kabul edilsin.
if [[ -n $K8S_IMAGE && $K8S_IMAGE != *"/"* ]]; then
  K8S_IMAGE="kindest/node:${K8S_IMAGE}"
fi

CONTEXT="kind-${NAME}"

# --- On kontroller ---------------------------------------------------------

require_cmd kind "Kurulum: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
require_cmd kubectl "Kurulum: sudo snap install kubectl --classic"
require_cmd docker "Kurulum: sudo apt install docker.io"

docker info >/dev/null 2>&1 ||
  die "Docker calismiyor gorunuyor. 'systemctl --user status docker' veya 'sudo systemctl start docker' deneyin."

# --- Yardimcilar -----------------------------------------------------------

cluster_exists() {
  kind get clusters 2>/dev/null | grep -qx -- "$1"
}

# check_inotify: kind'in en sik takildigi yer. Her node kendi kubelet/containerd
# izleyicilerini acar; limit dusukse ikinci cluster "wait-control-plane" fazinda
# zaman asimina ugrar ve hata mesaji sebebi hic gostermez.
# kind'in onerdigi degerler: instances >= 512, watches >= 524288.
check_inotify() {
  local instances watches running
  instances="$(sysctl -n fs.inotify.max_user_instances 2>/dev/null || echo 0)"
  watches="$(sysctl -n fs.inotify.max_user_watches 2>/dev/null || echo 0)"
  running="$(docker ps --filter 'label=io.x-k8s.kind.cluster' -q 2>/dev/null | grep -c . || true)"
  running="${running:-0}"

  if ((instances >= 512 && watches >= 524288)); then
    return 0
  fi

  log_warn "inotify limitleri kind'in onerdiginin altinda:"
  ((instances < 512)) &&
    log_dim "fs.inotify.max_user_instances = ${instances}  (onerilen: 512)"
  ((watches < 524288)) &&
    log_dim "fs.inotify.max_user_watches   = ${watches}  (onerilen: 524288)"

  if ((running > 0)); then
    log_warn "Su an ${running} kind node'u zaten calisiyor; yeni cluster limite takilabilir."
  fi
  log_dim "Kalici olarak yukseltmek icin:"
  log_cmd "printf 'fs.inotify.max_user_instances=512\\nfs.inotify.max_user_watches=524288\\n' | sudo tee /etc/sysctl.d/99-kind.conf && sudo sysctl --system"
  printf '\n'
  return 0
}

# generate_kind_config: node listesi, imaj deposu yamasi ve ingress port
# eslemesini iceren kind yapilandirmasini uretir.
generate_kind_config() {
  local file=$1 i
  {
    printf 'kind: Cluster\napiVersion: kind.x-k8s.io/v1alpha4\n'
    printf 'name: %s\n' "$NAME"

    if [[ $WITH_REGISTRY == "1" ]]; then
      # containerd'ye "certs.d" dizinini kullanmasini soyler; her node'a
      # cluster kurulduktan sonra hosts.toml yaziyoruz.
      cat <<'EOF'
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry]
      config_path = "/etc/containerd/certs.d"
EOF
    fi

    printf 'nodes:\n'
    printf '  - role: control-plane\n'
    if [[ -n $K8S_IMAGE ]]; then
      printf '    image: %s\n' "$K8S_IMAGE"
    fi

    if [[ $WITH_INGRESS == "1" ]]; then
      # ingress-nginx yalnizca bu etiketi tasiyan node'a kurulur.
      cat <<EOF
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: ${HTTP_PORT}
        protocol: TCP
      - containerPort: 443
        hostPort: ${HTTPS_PORT}
        protocol: TCP
EOF
    fi

    # `seq` kullaniliyor: WORKERS=0 durumunda dongu hic donmez ve C tarzi
    # `for ((...))` kosulunun son degerlendirmesi ERR trap'i tetiklemez.
    for _ in $(seq "$WORKERS"); do
      printf '  - role: worker\n'
      if [[ -n $K8S_IMAGE ]]; then
        printf '    image: %s\n' "$K8S_IMAGE"
      fi
    done
  } >"$file"
}

# start_registry: yerel imaj deposu konteynerini (yoksa) baslatir.
start_registry() {
  local state
  state="$(docker inspect -f '{{.State.Running}}' "$REG_NAME" 2>/dev/null || true)"

  if [[ $state == "true" ]]; then
    log_ok "Imaj deposu zaten calisiyor (${REG_NAME})"
    return 0
  fi

  if [[ -n $state ]]; then
    with_spinner "Duran imaj deposu baslatiliyor" docker start "$REG_NAME"
    return 0
  fi

  with_spinner "Imaj deposu olusturuluyor (localhost:${REG_PORT})" \
    docker run -d --restart=always \
    -p "127.0.0.1:${REG_PORT}:5000" \
    --name "$REG_NAME" \
    registry:2
}

# connect_registry: depoyu kind agina baglar ve her node'a adresini tanitir.
connect_registry() {
  # Ag baglantisi zaten varsa docker hata verir; sorun degil.
  docker network connect kind "$REG_NAME" >/dev/null 2>&1 || true

  local node
  for node in $(kind get nodes --name "$NAME" 2>/dev/null); do
    docker exec "$node" mkdir -p "/etc/containerd/certs.d/localhost:${REG_PORT}"
    printf '[host."http://%s:5000"]\n' "$REG_NAME" |
      docker exec -i "$node" cp /dev/stdin "/etc/containerd/certs.d/localhost:${REG_PORT}/hosts.toml"
  done

  # Cluster icindeki araclarin depoyu kesfedebilmesi icin standart ConfigMap.
  kubectl --context "$CONTEXT" apply -f - >/dev/null <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REG_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
}

install_ingress() {
  with_spinner "ingress-nginx kuruluyor" \
    kubectl --context "$CONTEXT" apply -f "$INGRESS_MANIFEST" ||
    {
      log_warn "ingress-nginx kurulamadi (internet erisimi gerekir)."
      return 0
    }

  with_spinner "ingress-nginx hazir olmasi bekleniyor" \
    kubectl --context "$CONTEXT" wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s ||
    log_warn "ingress-nginx zaman asimina ugradi; 'kubectl -n ingress-nginx get pods' ile kontrol edin."
}

# --- Akis ------------------------------------------------------------------

banner "kind lab" "cluster: ${NAME} · 1 control-plane + ${WORKERS} worker"

check_inotify

if cluster_exists "$NAME"; then
  if ((RECREATE == 0)); then
    log_warn "'${NAME}' adinda bir cluster zaten var."
    log_dim "Yeniden kurmak icin : make kind-reset KIND_NAME=${NAME}"
    log_dim "Duruma bakmak icin  : make kind-status KIND_NAME=${NAME}"
    printf '\n'
    exit 0
  fi
  log_warn "'${NAME}' siliniyor (--force)"
  with_spinner "Eski cluster siliniyor" kind delete cluster --name "$NAME"
fi

if [[ $WITH_REGISTRY == "1" ]]; then
  log_step "Yerel imaj deposu"
  start_registry
fi

log_step "Cluster olusturuluyor"
CONFIG_FILE="$(mktemp -t kind-config.XXXXXX.yaml)"
TMP_FILES+=("$CONFIG_FILE")
generate_kind_config "$CONFIG_FILE"

if ! with_spinner "kind cluster '${NAME}' kuruluyor" \
  kind create cluster --name "$NAME" --config "$CONFIG_FILE" --wait 60s; then
  log_err "Cluster kurulamadi."
  # En sik iki sebep; hata ciktisi bunlari kendisi soylemez.
  log_dim "1) 'wait-control-plane' zaman asimi genellikle inotify limitidir."
  log_dim "   Yukaridaki uyariya bakin veya daha az node deneyin:"
  log_cmd "make kind-up KIND_WORKERS=0"
  log_dim "2) Ayrintili cikti icin komutu elle calistirin:"
  log_cmd "kind create cluster --name ${NAME} --config ${CONFIG_FILE} --retain"
  # Uretilen yapilandirma hata ayiklamada gerektigi icin bu durumda silinmez.
  TMP_FILES=()
  printf '\n'
  exit 1
fi

if [[ $WITH_REGISTRY == "1" ]]; then
  log_step "Imaj deposu cluster'a baglaniyor"
  connect_registry
  log_ok "localhost:${REG_PORT} tum node'lara tanitildi"
fi

if [[ $WITH_INGRESS == "1" ]]; then
  log_step "Ingress"
  install_ingress
fi

# --- Ozet ------------------------------------------------------------------

log_step "Dogrulama"
if kubectl --context "$CONTEXT" get nodes >/dev/null 2>&1; then
  log_ok "Cluster erisilebilir (context: ${CONTEXT})"
else
  log_err "Cluster'a erisilemiyor (context: ${CONTEXT})"
fi

# kind'in --wait suresi control-plane icindir; worker'lar CNI hazir olana kadar
# birkac saniye NotReady kalir. "Hazir" demeden once hepsini bekliyoruz.
if ((WORKERS > 0)); then
  with_spinner "Node'larin hazir olmasi bekleniyor" \
    kubectl --context "$CONTEXT" wait --for=condition=Ready nodes --all --timeout=120s ||
    log_warn "Bazi node'lar hala hazir degil; 'make kind-status' ile kontrol edin."
fi

# Node'lar "Ready" gorunse bile sistem pod'lari cokmus olabilir. En sik sebep
# yine inotify limiti: kube-proxy "too many open files" ile crash loop'a girer
# ve cluster sessizce yarim calisir.
crashed="$(kubectl --context "$CONTEXT" get pods -A --no-headers 2>/dev/null |
  awk '$4 ~ /CrashLoopBackOff|Error/ {print $1 "/" $2}' | head -5 || true)"
if [[ -n $crashed ]]; then
  log_err "Bazi sistem pod'lari calismiyor:"
  printf '%s\n' "$crashed" | sed 's/^/      /'
  log_dim "Sebebi gormek icin:"
  log_cmd "kubectl --context ${CONTEXT} -n kube-system logs -l k8s-app=kube-proxy --tail=5"
  log_dim "'too many open files' yaziyorsa inotify limiti yetmiyor demektir:"
  log_cmd "printf 'fs.inotify.max_user_instances=512\\nfs.inotify.max_user_watches=524288\\n' | sudo tee /etc/sysctl.d/99-kind.conf && sudo sysctl --system"
  log_dim "Limiti yukselttikten sonra: make kind-reset"
else
  log_ok "Sistem pod'lari saglikli"
fi

printf '\n'
kubectl --context "$CONTEXT" get nodes 2>/dev/null | sed 's/^/  /'

banner "Hazir" "context: ${CONTEXT}"
printf '  %sKullanim%s\n' "$C_BOLD" "$C_RESET"
log_cmd "kubectl config use-context ${CONTEXT}"

if [[ $WITH_REGISTRY == "1" ]]; then
  printf '\n  %sImaji cluster icine tasi (kind load gerekmez)%s\n' "$C_BOLD" "$C_RESET"
  log_cmd "docker build -t localhost:${REG_PORT}/uygulama:dev ."
  log_cmd "docker push localhost:${REG_PORT}/uygulama:dev"
  log_dim "Manifest icinde: image: localhost:${REG_PORT}/uygulama:dev"
fi

if [[ $WITH_INGRESS == "1" ]]; then
  printf '\n  %sIngress%s\n' "$C_BOLD" "$C_RESET"
  log_dim "http://localhost:${HTTP_PORT}  ·  https://localhost:${HTTPS_PORT}"
fi

printf '\n  %sDiger%s\n' "$C_BOLD" "$C_RESET"
log_cmd "make kind-status"
log_cmd "make kind-down"
printf '\n'
