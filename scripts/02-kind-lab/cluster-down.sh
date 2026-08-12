#!/usr/bin/env bash
#
# cluster-down.sh - kind cluster'ini ve ardinda biraktigi izleri siler.
#
# kind, cluster'i silerken kubeconfig girdilerini de temizler; yine de elle
# silinmis veya cokmus cluster'lardan artakalan context/cluster/user kayitlari
# burada ayrica denetlenir.
#
# Yerel imaj deposu (registry) varsayilan olarak KORUNUR: birden fazla cluster
# ayni depoyu kullanabilir ve icindeki imajlar yeniden kurulumda ise yarar.
# Silmek icin --purge-registry kullanin.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh disable=SC1091
source "${REPO_ROOT}/lib/common.sh"
enable_error_trap

NAME="lab"
REG_NAME="kind-registry"
PURGE_REGISTRY=0
QUIET=0

usage() {
  cat <<'EOF'
Kullanim: cluster-down.sh [SECENEKLER]

Secenekler:
  --name <ad>         Silinecek cluster (varsayilan: lab)
  --purge-registry    Yerel imaj deposu konteynerini de siler
  --quiet             Silinecek bir sey yoksa hic ciktı vermez
  --yes               Onay sorularini atlar
  --no-color          Renkli ciktiyi kapatir
  -h, --help          Bu yardimi gosterir
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      NAME="$2"
      shift 2
      ;;
    --purge-registry)
      PURGE_REGISTRY=1
      shift
      ;;
    --quiet)
      QUIET=1
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

require_cmd kind "Kurulum: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"

CONTEXT="kind-${NAME}"

cluster_exists() {
  kind get clusters 2>/dev/null | grep -qx -- "$NAME"
}

context_exists() {
  kubectl config get-contexts -o name 2>/dev/null | grep -qx -- "$CONTEXT"
}

# --- Silinecek bir sey var mi? ---------------------------------------------

if ! cluster_exists && ! context_exists; then
  if ((QUIET == 1)); then
    exit 0
  fi
  banner "kind lab temizligi" "cluster: ${NAME}"
  log_ok "'${NAME}' zaten yok, yapilacak bir sey kalmadi."
  printf '\n'
  exit 0
fi

banner "kind lab temizligi" "cluster: ${NAME}"

if cluster_exists; then
  log_info "Silinecek cluster: ${NAME}"
  kind get nodes --name "$NAME" 2>/dev/null | sed 's/^/      /'
fi
((PURGE_REGISTRY == 1)) && log_warn "Yerel imaj deposu da silinecek (${REG_NAME})"

if ! confirm "Devam edilsin mi?"; then
  log_info "Iptal edildi."
  printf '\n'
  exit 0
fi

# --- Silme -----------------------------------------------------------------

if cluster_exists; then
  log_step "Cluster siliniyor"
  with_spinner "kind delete cluster --name ${NAME}" kind delete cluster --name "$NAME" ||
    log_err "Cluster silinemedi."
fi

# kind normalde kubeconfig'i temizler; cokmus cluster'larda artik kalabilir.
if context_exists; then
  log_step "kubeconfig temizligi"
  kubectl config delete-context "$CONTEXT" >/dev/null 2>&1 && log_ok "context silindi: ${CONTEXT}"
  kubectl config delete-cluster "$CONTEXT" >/dev/null 2>&1 && log_ok "cluster girdisi silindi: ${CONTEXT}"
  kubectl config unset "users.${CONTEXT}" >/dev/null 2>&1 && log_ok "kullanici girdisi silindi: ${CONTEXT}"
fi

if ((PURGE_REGISTRY == 1)); then
  log_step "Yerel imaj deposu"
  if docker inspect "$REG_NAME" >/dev/null 2>&1; then
    with_spinner "${REG_NAME} siliniyor" docker rm -f "$REG_NAME" ||
      log_err "Imaj deposu silinemedi."
  else
    log_info "Imaj deposu zaten yok."
  fi
fi

# --- Dogrulama -------------------------------------------------------------

log_step "Dogrulama"
if cluster_exists; then
  log_err "'${NAME}' hala duruyor."
else
  log_ok "'${NAME}' tamamen silindi."
fi

remaining="$(kind get clusters 2>/dev/null | tr '\n' ' ' | sed 's/ $//')"
if [[ -n $remaining ]]; then
  log_info "Duran diger cluster'lar: ${remaining}"
else
  log_info "Makinede kind cluster'i kalmadi."
fi

if ((PURGE_REGISTRY == 0)) && docker inspect "$REG_NAME" >/dev/null 2>&1; then
  log_dim "Yerel imaj deposu korundu. Silmek icin: ${0##*/} --purge-registry"
fi
printf '\n'
