#!/usr/bin/env bash
#
# vm-info.sh - Kurulu makinelerin durumunu ve baglanti bilgilerini gosterir.
#
#   make mp-status    -> --mode status : durum, IP, CPU, bellek ve disk kullanimi
#   make mp-ssh-info  -> --mode ssh    : kopyalanabilir SSH komutlari

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh disable=SC1091
source "${REPO_ROOT}/lib/common.sh"
enable_error_trap

MODE="status"
NODES="master worker datanode singlenode"
VM_USER="cluster"
VM_PASS="cluster"

usage() {
  cat <<'EOF'
Kullanim: vm-info.sh [SECENEKLER]

Secenekler:
  --mode <status|ssh>      Gosterilecek bilgi turu (varsayilan: status)
  --nodes "<ad1 ad2 ...>"  Sorgulanacak makine adlari
  --user <ad>              SSH kullanici adi (varsayilan: cluster)
  --pass <parola>          Ciktida gosterilecek parola (varsayilan: cluster)
  --no-color               Renkli ciktiyi kapatir
  -h, --help               Bu yardimi gosterir
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --nodes)
      NODES="$2"
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

require_cmd multipass "Kurulum icin: make mp-install-deps"
read -r -a NODE_LIST <<<"$NODES"

vm_exists() {
  multipass list --format csv 2>/dev/null | awk -F, -v n="$1" 'NR>1 && $1==n {found=1} END {exit !found}'
}

vm_ip() {
  multipass list --format csv 2>/dev/null | awk -F, -v n="$1" 'NR>1 && $1==n {print $3; exit}'
}

vm_state() {
  multipass list --format csv 2>/dev/null | awk -F, -v n="$1" 'NR>1 && $1==n {print $2; exit}'
}

# info_field <ad> <alan>: `multipass info` tablo ciktisindan bir alani ceker.
# Ornek: info_field master "CPU(s)" -> 2
info_field() {
  local node=$1 field=$2
  multipass info "$node" 2>/dev/null |
    awk -v f="${field}:" 'index($0, f) == 1 { sub(/^[^:]*:[ \t]*/, ""); print; exit }'
}

ACTIVE_NODES=()
for node in "${NODE_LIST[@]}"; do
  vm_exists "$node" && ACTIVE_NODES+=("$node")
done

if ((${#ACTIVE_NODES[@]} == 0)); then
  banner "Durum" "kurulu makine yok"
  log_info "Bu modulun makinelerinden hicbiri kurulu degil."
  log_dim "Kurmak icin: make mp-cluster  veya  make mp-singlenode"
  printf '\n'
  exit 0
fi

case "$MODE" in
  status)
    banner "Makine durumu" "${#ACTIVE_NODES[@]} makine kurulu"
    printf '  %s%s %s %s %s %s %s%s\n' "$C_BOLD" \
      "$(pad "MAKINE" 14)" "$(pad "DURUM" 10)" "$(pad "IP" 17)" \
      "$(pad "CPU" 5)" "$(pad "BELLEK" 24)" "DISK" "$C_RESET"
    hr
    for node in "${ACTIVE_NODES[@]}"; do
      state="$(vm_state "$node")"
      color=$C_GREEN
      [[ $state != "Running" ]] && color=$C_YELLOW
      printf '  %s %s%s%s %s %s %s %s\n' \
        "$(pad "$node" 14)" \
        "$color" "$(pad "$state" 10)" "$C_RESET" \
        "$(pad "$(vm_ip "$node")" 17)" \
        "$(pad "$(info_field "$node" 'CPU(s)')" 5)" \
        "$(pad "$(info_field "$node" 'Memory usage')" 24)" \
        "$(info_field "$node" 'Disk usage')"
    done
    hr
    printf '\n  %sKomutlar%s\n' "$C_BOLD" "$C_RESET"
    log_cmd "make mp-ssh-info      # baglanti bilgileri"
    log_cmd "make mp-clean         # makineleri sil"
    printf '\n'
    ;;

  ssh)
    banner "SSH baglanti bilgileri" "kullanici: ${VM_USER} · parola: ${VM_PASS}"
    for node in "${ACTIVE_NODES[@]}"; do
      ip="$(vm_ip "$node")"
      printf '  %s%s%s (%s)\n' "$C_BOLD" "$node" "$C_RESET" "$(vm_state "$node")"
      if [[ -n $ip ]]; then
        log_cmd "ssh ${VM_USER}@${ip}"
        if has_cmd sshpass; then
          log_cmd "sshpass -p '${VM_PASS}' ssh -o StrictHostKeyChecking=no ${VM_USER}@${ip}"
        fi
      else
        log_warn "IP adresi yok (makine calismiyor olabilir)"
      fi
      log_cmd "multipass shell ${node}"
      printf '\n'
    done
    log_info "Parola ile giris acik; ilk baglantida host anahtarini onaylamaniz istenir."
    printf '\n'
    ;;

  *)
    die "Gecersiz mod: ${MODE} (status veya ssh olmali)"
    ;;
esac
