#!/usr/bin/env bash
#
# install-deps.sh - Bu modulun ihtiyac duydugu araclari kurar.
#
# preflight.sh hicbir sey kurmaz; kurulum yalnizca bu script ile ve kullanicinin
# acik onayiyla yapilir (sudo gerekir).
#
# Kurulan/kontrol edilen araclar:
#   multipass  (snap)  - sanal makineleri olusturur           [zorunlu]
#   openssh-client     - makinelere baglanmak icin            [zorunlu]
#   sshpass            - parola ile SSH girisini test etmek    [opsiyonel]

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh disable=SC1091
source "${REPO_ROOT}/lib/common.sh"
enable_error_trap

usage() {
  cat <<'EOF'
Kullanim: install-deps.sh [SECENEKLER]

Secenekler:
  --yes         Onay sorularini atlar
  --no-color    Renkli ciktiyi kapatir
  -h, --help    Bu yardimi gosterir
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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

# --- Dagitim tespiti -------------------------------------------------------

DISTRO_ID="bilinmiyor"
DISTRO_NAME="bilinmiyor"
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  DISTRO_ID="${ID:-bilinmiyor}"
  DISTRO_NAME="${PRETTY_NAME:-$DISTRO_ID}"
fi

banner "Bagimlilik kurulumu" "sistem: ${DISTRO_NAME}"

# --- Eksiklerin tespiti ----------------------------------------------------

MISSING_SNAP=()
MISSING_APT=()

if has_cmd multipass; then
  log_ok "multipass zaten kurulu ($(multipass version 2>/dev/null | awk 'NR==1 {print $2}'))"
else
  log_warn "multipass kurulu degil"
  MISSING_SNAP+=("multipass")
fi

if has_cmd ssh; then
  log_ok "openssh-client zaten kurulu"
else
  log_warn "openssh-client kurulu degil"
  MISSING_APT+=("openssh-client")
fi

if has_cmd sshpass; then
  log_ok "sshpass zaten kurulu (opsiyonel)"
else
  log_warn "sshpass kurulu degil (opsiyonel: parola ile SSH testi icin)"
  MISSING_APT+=("sshpass")
fi

if ((${#MISSING_SNAP[@]} == 0 && ${#MISSING_APT[@]} == 0)); then
  printf '\n'
  log_ok "Tum bagimliliklar hazir, yapilacak bir sey yok."
  log_dim "Sistemi denetlemek icin: make preflight"
  printf '\n'
  exit 0
fi

# --- Desteklenmeyen dagitimlar ---------------------------------------------

case "$DISTRO_ID" in
  ubuntu | debian | linuxmint | pop | elementary | zorin)
    : # apt + snap ile devam
    ;;
  *)
    printf '\n'
    log_warn "Otomatik kurulum yalnizca Debian/Ubuntu tabanli sistemlerde destekleniyor."
    log_info "Elle kurulum icin:"
    log_cmd "multipass  -> https://canonical.com/multipass/install"
    log_cmd "sshpass    -> dagitiminizin paket yoneticisi ile"
    printf '\n'
    exit 1
    ;;
esac

# --- Onay ------------------------------------------------------------------

printf '\n  %sKurulacaklar%s\n' "$C_BOLD" "$C_RESET"
((${#MISSING_SNAP[@]} > 0)) && log_info "snap : ${MISSING_SNAP[*]}"
((${#MISSING_APT[@]} > 0)) && log_info "apt  : ${MISSING_APT[*]}"
printf '\n'
log_warn "Bu islem 'sudo' ile paket kurar."

if ! confirm "Kuruluma devam edilsin mi?"; then
  log_info "Iptal edildi."
  printf '\n'
  exit 0
fi

# --- Kurulum ---------------------------------------------------------------

if ((${#MISSING_APT[@]} > 0)); then
  log_step "apt paketleri kuruluyor"
  with_spinner "apt-get update" sudo apt-get update -qq ||
    log_warn "apt-get update basarisiz oldu, kuruluma yine de devam ediliyor."
  with_spinner "kuruluyor: ${MISSING_APT[*]}" \
    sudo apt-get install -y -qq "${MISSING_APT[@]}" ||
    die "apt paketleri kurulamadi."
fi

if ((${#MISSING_SNAP[@]} > 0)); then
  log_step "snap paketleri kuruluyor"
  if ! has_cmd snap; then
    with_spinner "snapd kuruluyor" sudo apt-get install -y -qq snapd ||
      die "snapd kurulamadi."
  fi
  with_spinner "multipass kuruluyor (birkac dakika surebilir)" \
    sudo snap install multipass ||
    die "multipass kurulamadi. Elle deneyin: sudo snap install multipass"

  # Snap kurulumundan hemen sonra daemon birkac saniye hazir olmayabilir.
  log_step "multipass servisi bekleniyor"
  for _ in {1..30}; do
    if multipass version >/dev/null 2>&1; then
      log_ok "multipassd yanit veriyor"
      break
    fi
    sleep 1
  done
fi

# --- Sonuc -----------------------------------------------------------------

log_step "Sonuc"
if has_cmd multipass && multipass version >/dev/null 2>&1; then
  log_ok "multipass hazir: $(multipass version 2>/dev/null | awk 'NR==1 {print $2}')"
else
  log_err "multipass hala calismiyor. Servisi kontrol edin: snap services multipass"
fi

printf '\n'
log_info "Simdi sistemi denetleyin:"
log_cmd "make preflight"
printf '\n'
