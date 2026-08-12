#!/usr/bin/env bash
#
# vm-clean.sh - Bu modulun olusturdugu makineleri iz birakmadan siler.
#
# Yapilanlar:
#   1. Makineler durdurulur ve --purge ile silinir (geri donusu yoktur)
#   2. Multipass'in silinmis makine artiklari temizlenir (multipass purge)
#   3. Makinelerin IP adreslerine ait SSH host anahtarlari known_hosts'tan silinir
#
# Boylece ayni adla yeniden kurulum yapildiginda "REMOTE HOST IDENTIFICATION
# HAS CHANGED" uyarisi alinmaz.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh disable=SC1091
source "${REPO_ROOT}/lib/common.sh"
enable_error_trap

NODES="master worker datanode singlenode"
CLEAN_ALL=0

usage() {
  cat <<'EOF'
Kullanim: vm-clean.sh [SECENEKLER]

Secenekler:
  --nodes "<ad1 ad2 ...>"  Silinecek makine adlari
                           (varsayilan: master worker datanode singlenode)
  --name <ad>              Yalnizca tek bir makineyi siler
  --all                    Multipass'teki TUM makineleri siler (ekstra onay ister)
  --yes                    Onay sorularini atlar
  --no-color               Renkli ciktiyi kapatir
  -h, --help               Bu yardimi gosterir

Ornekler:
  ./vm-clean.sh                  # modulun makinelerini sil
  ./vm-clean.sh --name worker    # sadece worker
  ./vm-clean.sh --all --yes      # her seyi sil, sorma
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --nodes)
      NODES="$2"
      shift 2
      ;;
    --name)
      NODES="$2"
      shift 2
      ;;
    --all)
      CLEAN_ALL=1
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

require_cmd multipass "Multipass kurulu degil; silinecek makine de yok."

# --- Hedeflerin belirlenmesi -----------------------------------------------

all_vm_names() {
  multipass list --format csv 2>/dev/null | awk -F, 'NR>1 && $1 != "" {print $1}'
}

vm_ip() {
  multipass list --format csv 2>/dev/null | awk -F, -v n="$1" 'NR>1 && $1==n {print $3; exit}'
}

vm_state() {
  multipass list --format csv 2>/dev/null | awk -F, -v n="$1" 'NR>1 && $1==n {print $2; exit}'
}

TARGETS=()
if ((CLEAN_ALL == 1)); then
  banner "Temizlik - TUM makineler" "multipass uzerindeki her sey silinecek"
  mapfile -t TARGETS < <(all_vm_names)
else
  banner "Temizlik" "01-multipass-cluster-maker makineleri"
  read -r -a WANTED <<<"$NODES"
  existing="$(all_vm_names)"
  for node in "${WANTED[@]}"; do
    if grep -qx -- "$node" <<<"$existing"; then
      TARGETS+=("$node")
    fi
  done
fi

if ((${#TARGETS[@]} == 0)); then
  log_ok "Silinecek makine yok, sistem zaten temiz."
  printf '\n'
  exit 0
fi

# --- Onay ------------------------------------------------------------------

printf '  %s%s %s %s%s\n' "$C_BOLD" "$(pad "MAKINE" 16)" "$(pad "DURUM" 12)" "IP" "$C_RESET"
hr
IPS=()
for node in "${TARGETS[@]}"; do
  ip="$(vm_ip "$node")"
  [[ -n $ip ]] && IPS+=("$ip")
  printf '  %s %s %s\n' "$(pad "$node" 16)" "$(pad "$(vm_state "$node")" 12)" "${ip:-yok}"
done
hr
printf '\n'
log_warn "Bu islem geri alinamaz: makineler ve diskleri kalici olarak silinir."

if ((CLEAN_ALL == 1)); then
  log_warn "--all verildi: modul disindaki makineler de silinecek!"
fi

if ! confirm "${#TARGETS[@]} makine silinsin mi?"; then
  log_info "Iptal edildi, hicbir sey silinmedi."
  printf '\n'
  exit 0
fi

# --- Silme -----------------------------------------------------------------

log_step "Makineler durduruluyor"
for node in "${TARGETS[@]}"; do
  if [[ "$(vm_state "$node")" == "Running" ]]; then
    with_spinner "${node} durduruluyor" multipass stop --force "$node" ||
      log_warn "${node} durdurulamadi, silme yine de denenecek."
  else
    log_info "${node} zaten calismiyor"
  fi
done

log_step "Makineler siliniyor"
for node in "${TARGETS[@]}"; do
  with_spinner "${node} siliniyor (--purge)" multipass delete --purge "$node" ||
    log_err "${node} silinemedi."
done

log_step "Artiklar temizleniyor"
with_spinner "multipass purge" multipass purge || log_warn "purge basarisiz oldu."

if ((${#IPS[@]} > 0)) && has_cmd ssh-keygen; then
  log_step "SSH known_hosts temizligi"
  for ip in "${IPS[@]}"; do
    if ssh-keygen -R "$ip" >/dev/null 2>&1; then
      log_ok "${ip} icin host anahtari silindi"
    else
      log_info "${ip} icin kayit bulunamadi"
    fi
  done
fi

# --- Dogrulama -------------------------------------------------------------

log_step "Dogrulama"
remaining=()
existing="$(all_vm_names)"
for node in "${TARGETS[@]}"; do
  if grep -qx -- "$node" <<<"$existing"; then
    remaining+=("$node")
  fi
done

if ((${#remaining[@]} == 0)); then
  log_ok "Hedeflenen ${#TARGETS[@]} makine tamamen silindi."
else
  log_err "Hala duran makineler var: ${remaining[*]}"
fi

printf '\n  %sMultipass mevcut durumu%s\n' "$C_BOLD" "$C_RESET"
multipass list 2>/dev/null | sed 's/^/    /'
printf '\n'

((${#remaining[@]} == 0)) || exit 1
