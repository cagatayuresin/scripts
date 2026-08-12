#!/usr/bin/env bash
#
# vm-up.sh - Multipass ile Ubuntu sanal makineleri olusturur.
#
# Iki senaryoda da ayni script calisir:
#   make mp-cluster    -> --profile cluster    --nodes "master worker datanode"
#   make mp-singlenode -> --profile singlenode --nodes "singlenode"
#
# Her makine ayni sablondan (cloud-init/node.yaml) uretilir: parola ile SSH
# girisi acik, sudo yetkili bir kullanici hazir gelir.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh disable=SC1091
source "${REPO_ROOT}/lib/common.sh"
enable_error_trap

TEMPLATE="${SCRIPT_DIR}/cloud-init/node.yaml"

# /etc/hosts icine yazilan yonetilen blogun sinirlari
HOSTS_MARKER_START="# >>> multipass-cluster-maker >>>"
HOSTS_MARKER_END="# <<< multipass-cluster-maker <<<"

# --- Varsayilanlar ---------------------------------------------------------
PROFILE="cluster"
NODES="master worker datanode"
CPUS="2"
MEMORY="4G"
DISK="10G"
RELEASE="24.04"
VM_USER="cluster"
VM_PASS="cluster"
RECREATE=0
LAUNCH_TIMEOUT=600

CREATED_NODES=()
SKIPPED_NODES=()
TMP_FILES=()
# render_cloud_init uretilen dosyanin yolunu buraya yazar; komut ikamesi
# ($(...)) kullanilsaydi dosya listesi alt kabukta kalir ve silinemezdi.
RENDERED_CI=""

# Uretilen cloud-init dosyalari parola icerir; her durumda silinmeleri gerekir.
cleanup() {
  local f
  for f in "${TMP_FILES[@]}"; do
    if [[ -n $f && -f $f ]]; then
      rm -f "$f"
    fi
  done
  # EXIT trap'inin donus degeri scriptin cikis kodunu ezer; sifir birakiyoruz.
  return 0
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
Kullanim: vm-up.sh [SECENEKLER]

Secenekler:
  --profile <cluster|singlenode>  Senaryo adi (ciktida gosterilir)
  --nodes "<ad1 ad2 ...>"         Olusturulacak makine adlari
  --cpus <n>                      Makine basina vCPU (varsayilan: 2)
  --memory <boyut>                Makine basina RAM (varsayilan: 4G)
  --disk <boyut>                  Makine basina disk (varsayilan: 10G)
  --release <surum>               Ubuntu surumu (varsayilan: 24.04)
  --user <ad>                     Olusturulacak kullanici (varsayilan: cluster)
  --pass <parola>                 Kullanicinin parolasi (varsayilan: cluster)
  --force                         Ayni adli makine varsa silip yeniden kurar
  --yes                           Onay sorularini atlar
  --no-color                      Renkli ciktiyi kapatir
  -h, --help                      Bu yardimi gosterir

Ornekler:
  ./vm-up.sh --profile singlenode --nodes "singlenode"
  ./vm-up.sh --nodes "master worker datanode" --cpus 4 --memory 8G
EOF
}

# --- Argumanlar ------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --nodes)
      NODES="$2"
      shift 2
      ;;
    --cpus)
      CPUS="$2"
      shift 2
      ;;
    --memory)
      MEMORY="$2"
      shift 2
      ;;
    --disk)
      DISK="$2"
      shift 2
      ;;
    --release)
      RELEASE="$2"
      shift 2
      ;;
    --user)
      VM_USER="$2"
      shift 2
      ;;
    --pass)
      VM_PASS="$2"
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

read -r -a NODE_LIST <<<"$NODES"
((${#NODE_LIST[@]} > 0)) || die "En az bir makine adi gerekli (--nodes)"
[[ -f $TEMPLATE ]] || die "cloud-init sablonu bulunamadi: $TEMPLATE"
require_cmd multipass "Kurulum icin: make mp-install-deps"

# --- Yardimcilar -----------------------------------------------------------

# vm_exists <ad>: multipass'te bu adda bir makine var mi?
vm_exists() {
  multipass list --format csv 2>/dev/null | awk -F, -v n="$1" 'NR>1 && $1==n {found=1} END {exit !found}'
}

# vm_ip <ad>: makinenin IPv4 adresi (yoksa bos doner).
vm_ip() {
  multipass list --format csv 2>/dev/null | awk -F, -v n="$1" 'NR>1 && $1==n {print $3; exit}'
}

# vm_state <ad>: makinenin durumu (Running, Stopped ...).
vm_state() {
  multipass list --format csv 2>/dev/null | awk -F, -v n="$1" 'NR>1 && $1==n {print $2; exit}'
}

# render_cloud_init <ad>: sablondaki yer tutuculari doldurup gecici dosyaya yazar.
# Sonucu RENDERED_CI degiskenine koyar (komut ikamesi kullanilmaz, bkz. cleanup).
render_cloud_init() {
  local node=$1 content tmp
  content="$(<"$TEMPLATE")"
  content="${content//__NODE_NAME__/$node}"
  content="${content//__VM_USER__/$VM_USER}"
  # Parola YAML'da tek tirnak icinde; icindeki tek tirnaklar ikiye katlanmali.
  content="${content//__VM_PASS__/${VM_PASS//\'/\'\'}}"
  tmp="$(mktemp -t cloud-init-"${node}".XXXXXX.yaml)"
  TMP_FILES+=("$tmp")
  chmod 600 "$tmp"
  printf '%s\n' "$content" >"$tmp"
  RENDERED_CI="$tmp"
}

# wait_cloud_init <ad>: makine icinde cloud-init'in bitmesini bekler.
# `cloud-init status --wait` cikis kodlari: 0 = done, 2 = done ama duzeltilebilir
# uyarilar var (degraded). Ikisi de basari sayilir.
wait_cloud_init() {
  local node=$1 rc=0
  multipass exec "$node" -- cloud-init status --wait >/dev/null 2>&1 || rc=$?
  ((rc == 0 || rc == 2)) && return 0
  return "$rc"
}

# forget_host_key <ip>: eski SSH host anahtarini temizler (IP yeniden kullanilabilir).
forget_host_key() {
  local ip=$1
  [[ -n $ip && -f ${HOME}/.ssh/known_hosts ]] || return 0
  ssh-keygen -R "$ip" >/dev/null 2>&1 || true
}

# --- Adimlar ---------------------------------------------------------------

print_plan() {
  local title="Multipass lab kurulumu"
  [[ $PROFILE == "singlenode" ]] && title="Multipass tek makine kurulumu"
  banner "$title" "profil: ${PROFILE} · ${#NODE_LIST[@]} makine"

  printf '  %s%s %s %s%s\n' "$C_BOLD" \
    "$(pad "MAKINE" 16)" "$(pad "KAYNAK" 30)" "IMAJ" "$C_RESET"
  hr
  local node
  for node in "${NODE_LIST[@]}"; do
    printf '  %s %s Ubuntu %s\n' \
      "$(pad "$node" 16)" "$(pad "${CPUS} vCPU · ${MEMORY} RAM · ${DISK} disk" 30)" "$RELEASE"
  done
  hr
  printf '  Kullanici: %s%s%s   Parola: %s%s%s   SSH: %sparola ile acik%s\n' \
    "$C_BOLD" "$VM_USER" "$C_RESET" "$C_BOLD" "$VM_PASS" "$C_RESET" "$C_GREEN" "$C_RESET"
}

# Var olan makineleri ele al: --force ile sil, aksi halde atla.
handle_existing() {
  local existing=() node
  for node in "${NODE_LIST[@]}"; do
    vm_exists "$node" && existing+=("$node")
  done
  ((${#existing[@]} == 0)) && return 0

  if ((RECREATE == 0)); then
    log_step "Mevcut makineler"
    for node in "${existing[@]}"; do
      log_warn "'${node}' zaten var, atlaniyor (durum: $(vm_state "$node"))"
      SKIPPED_NODES+=("$node")
    done
    log_dim "Yeniden kurmak icin: make mp-${PROFILE} MP_RECREATE=1"
    log_dim "Tamamen silmek icin : make mp-clean"
    return 0
  fi

  log_step "Mevcut makineler siliniyor (MP_RECREATE=1)"
  log_warn "Silinecek: ${existing[*]}"
  if ! confirm "Bu makineler kalici olarak silinecek, devam edilsin mi?"; then
    die "Kullanici iptal etti."
  fi
  for node in "${existing[@]}"; do
    forget_host_key "$(vm_ip "$node")"
    with_spinner "${node} siliniyor" multipass delete --purge "$node"
  done
}

launch_nodes() {
  local node ci_file
  for node in "${NODE_LIST[@]}"; do
    # Atlanan (zaten var olan) makineleri yeniden kurma.
    if [[ " ${SKIPPED_NODES[*]:-} " == *" ${node} "* ]]; then
      continue
    fi

    log_step "Makine olusturuluyor: ${node}"
    log_dim "${CPUS} vCPU · ${MEMORY} RAM · ${DISK} disk · Ubuntu ${RELEASE}"
    render_cloud_init "$node"
    ci_file="$RENDERED_CI"

    # cloud-init dosya yolu yerine stdin ile veriliyor: multipass snap paketi
    # ne /tmp'yi (ozel ad alani) ne de HOME altindaki gizli dizinleri
    # (snap 'home' arayuzu nokta ile baslayan yollari kapsamaz) okuyabilir.
    # Dosyayi bash acip fd 0'a bagladigi icin bu kisitlarin hicbiri gecerli olmaz.
    SPINNER_STDIN="$ci_file" \
      with_spinner "'${node}' baslatiliyor (imaj indirilebilir, biraz surebilir)" \
      multipass launch "$RELEASE" \
      --name "$node" \
      --cpus "$CPUS" \
      --memory "$MEMORY" \
      --disk "$DISK" \
      --cloud-init - \
      --timeout "$LAUNCH_TIMEOUT" ||
      die "'${node}' olusturulamadi. Ayrinti icin: multipass launch ... komutunu elle deneyin."

    # cloud-init paketleri kurup kullaniciyi olusturana kadar bekle.
    if ! with_spinner "'${node}' icinde cloud-init tamamlaniyor" wait_cloud_init "$node"; then
      log_warn "cloud-init 'done' durumuna ulasamadi; makine yine de kullanilabilir."
      log_dim "Ayrinti: multipass exec ${node} -- sudo cloud-init status --long"
    fi

    forget_host_key "$(vm_ip "$node")"
    CREATED_NODES+=("$node")
  done
}

# Cluster senaryosunda dugumlerin birbirini adiyla gormesi icin /etc/hosts guncellenir.
sync_hosts_file() {
  ((${#NODE_LIST[@]} > 1)) || return 0

  local block="" node ip
  for node in "${NODE_LIST[@]}"; do
    ip="$(vm_ip "$node")"
    [[ -n $ip ]] && block+="${ip} ${node}"$'\n'
  done
  [[ -n $block ]] || return 0

  log_step "Dugumler arasi isim cozumleme (/etc/hosts)"
  local payload="${HOSTS_MARKER_START}"$'\n'"${block}${HOSTS_MARKER_END}"

  for node in "${NODE_LIST[@]}"; do
    vm_exists "$node" || continue
    if printf '%s\n' "$payload" | multipass exec "$node" -- sudo bash -c \
      "sed -i '/${HOSTS_MARKER_START}/,/${HOSTS_MARKER_END}/d' /etc/hosts && cat >> /etc/hosts" 2>/dev/null; then
      log_ok "${node}: diger dugumler /etc/hosts icine yazildi"
    else
      log_warn "${node}: /etc/hosts guncellenemedi (dugumlere IP ile erisebilirsiniz)"
    fi
  done
}

verify_nodes() {
  log_step "Dogrulama"
  local node ip

  for node in "${NODE_LIST[@]}"; do
    vm_exists "$node" || {
      log_err "${node}: makine bulunamadi"
      continue
    }
    ip="$(vm_ip "$node")"

    if multipass exec "$node" -- id "$VM_USER" >/dev/null 2>&1; then
      log_ok "${node}: '${VM_USER}' kullanicisi olusturuldu"
    else
      log_err "${node}: '${VM_USER}' kullanicisi bulunamadi"
    fi

    if multipass exec "$node" -- bash -c 'ss -ltn 2>/dev/null | grep -q ":22 "' >/dev/null 2>&1; then
      log_ok "${node}: SSH servisi 22 portunu dinliyor"
    else
      log_warn "${node}: 22 portu dinleme durumu dogrulanamadi"
    fi

    if has_cmd sshpass && [[ -n $ip ]]; then
      if sshpass -p "$VM_PASS" ssh \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        -o ConnectTimeout=10 \
        "${VM_USER}@${ip}" 'true' >/dev/null 2>&1; then
        log_ok "${node}: parola ile SSH girisi calisiyor (${VM_USER}@${ip})"
      else
        log_err "${node}: parola ile SSH girisi basarisiz (${VM_USER}@${ip})"
      fi
    fi
  done

  if ! has_cmd sshpass; then
    log_info "sshpass kurulu degil; parola ile SSH girisi otomatik test edilemedi."
    log_dim "Kurmak icin: sudo apt install sshpass"
  fi
}

print_summary() {
  banner "Kurulum tamamlandi" "profil: ${PROFILE}"

  printf '  %s%s %s %s %s%s\n' "$C_BOLD" \
    "$(pad "MAKINE" 14)" "$(pad "DURUM" 12)" "$(pad "IP" 18)" "BAGLANTI" "$C_RESET"
  hr
  local node ip state
  for node in "${NODE_LIST[@]}"; do
    ip="$(vm_ip "$node")"
    state="$(vm_state "$node")"
    printf '  %s %s %s %sssh %s@%s%s\n' \
      "$(pad "$node" 14)" "$(pad "${state:-yok}" 12)" "$(pad "${ip:-yok}" 18)" \
      "$C_MAGENTA" "$VM_USER" "${ip:-?}" "$C_RESET"
  done
  hr

  printf '\n  %sGiris bilgileri%s\n' "$C_BOLD" "$C_RESET"
  printf '    Kullanici : %s\n' "$VM_USER"
  printf '    Parola    : %s\n' "$VM_PASS"
  printf '    Yetki     : sudo (parolasiz)\n'

  printf '\n  %sSik kullanilan komutlar%s\n' "$C_BOLD" "$C_RESET"
  log_cmd "ssh ${VM_USER}@$(vm_ip "${NODE_LIST[0]}")"
  log_cmd "multipass shell ${NODE_LIST[0]}"
  log_cmd "make mp-status"
  log_cmd "make mp-clean"

  if ((${#SKIPPED_NODES[@]} > 0)); then
    printf '\n'
    log_warn "Atlanan (zaten var olan) makineler: ${SKIPPED_NODES[*]}"
  fi
  printf '\n'
}

main() {
  print_plan
  handle_existing
  launch_nodes
  sync_hosts_file
  verify_nodes
  print_summary
}

main
