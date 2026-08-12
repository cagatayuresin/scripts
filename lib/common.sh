#!/usr/bin/env bash
# common.sh - cagatayuresin/scripts deposundaki tum modullerin paylastigi yardimci kutuphane.
#
# Kullanim:
#   REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
#   source "${REPO_ROOT}/lib/common.sh"
#
# Icerik: renkli log fonksiyonlari, hizalanmis kontrol tablosu, spinner,
# boyut ayristirma (4G -> MiB), onay sorusu ve hata yakalama.

# Ayni surecte iki kez yuklenmesin.
if [[ -n ${COMMON_SH_LOADED:-} ]]; then
  return 0
fi
COMMON_SH_LOADED=1

# ---------------------------------------------------------------------------
# Renkler
# ---------------------------------------------------------------------------

C_RESET=""
C_BOLD=""
C_DIM=""
C_RED=""
C_GREEN=""
C_YELLOW=""
C_BLUE=""
C_CYAN=""
C_MAGENTA=""

# is_tty: stdout gercek bir terminale mi bagli?
is_tty() {
  [[ -t 1 ]]
}

# disable_colors: tum renk degiskenlerini bosaltir.
disable_colors() {
  C_RESET="" C_BOLD="" C_DIM="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_CYAN="" C_MAGENTA=""
}

# setup_colors: TTY varsa ve NO_COLOR tanimli degilse renkleri acar.
setup_colors() {
  if [[ -n ${NO_COLOR:-} ]] || ! is_tty || [[ ${TERM:-dumb} == "dumb" ]]; then
    disable_colors
    return 0
  fi
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_MAGENTA=$'\033[35m'
  C_CYAN=$'\033[36m'
}

setup_colors

# ---------------------------------------------------------------------------
# Metin yardimcilari
# ---------------------------------------------------------------------------

# pad <metin> <genislik>: metni verilen genislige kadar bosluk ile doldurur.
# printf '%-20s' bayt sayar; Turkce karakterler (c, g, i, o, s, u) cok baytli
# oldugu icin hizalamayi bozar. ${#s} ise locale'e gore karakter sayar.
pad() {
  local text=$1 width=$2 fill
  fill=$((width - ${#text}))
  if ((fill > 0)); then
    printf '%s%*s' "$text" "$fill" ''
  else
    printf '%s' "$text"
  fi
}

# hr [genislik]: yatay ayrac cizgisi.
hr() {
  local width=${1:-78} line=""
  local i
  for ((i = 0; i < width; i++)); do
    line+="─"
  done
  printf '%s%s%s\n' "$C_DIM" "$line" "$C_RESET"
}

# banner <baslik> [altbaslik]: cerceveli baslik blogu.
banner() {
  local title=$1 subtitle=${2:-}
  printf '\n'
  hr
  printf '%s%s %s%s\n' "$C_BOLD" "$C_CYAN" "$title" "$C_RESET"
  if [[ -n $subtitle ]]; then
    printf '%s  %s%s\n' "$C_DIM" "$subtitle" "$C_RESET"
  fi
  hr
}

# ---------------------------------------------------------------------------
# Log fonksiyonlari
# ---------------------------------------------------------------------------

log_step() { printf '\n%s%s▸ %s%s\n' "$C_BOLD" "$C_BLUE" "$1" "$C_RESET"; }
log_ok() { printf '  %s✔%s %s\n' "$C_GREEN" "$C_RESET" "$1"; }
log_warn() { printf '  %s⚠%s %s\n' "$C_YELLOW" "$C_RESET" "$1" >&2; }
log_err() { printf '  %s✖%s %s\n' "$C_RED" "$C_RESET" "$1" >&2; }
log_info() { printf '  %s·%s %s\n' "$C_CYAN" "$C_RESET" "$1"; }
log_dim() { printf '    %s%s%s\n' "$C_DIM" "$1" "$C_RESET"; }

# log_cmd: kullanicinin kopyalayabilecegi komut satiri.
log_cmd() { printf '    %s$ %s%s\n' "$C_MAGENTA" "$1" "$C_RESET"; }

# die <mesaj> [cikis_kodu]: hata bas ve cik.
# ERR trap'i kaldirir; aksi halde `exit 1` ikinci bir hata raporu bastirirdi.
die() {
  trap - ERR
  log_err "${1:-beklenmeyen hata}"
  exit "${2:-1}"
}

# ---------------------------------------------------------------------------
# Hata yakalama
# ---------------------------------------------------------------------------

# enable_error_trap: `set -Eeuo pipefail` ile birlikte kullanilir; hatanin
# hangi satirda ve hangi komutta olustugunu bildirir.
enable_error_trap() {
  # Dosya adi trap'in calistigi baglamda cozulur; _on_error icinden bakilsaydi
  # her zaman common.sh gorunurdu.
  trap '_on_error $? $LINENO "$BASH_COMMAND" "${BASH_SOURCE[0]}"' ERR
}

_on_error() {
  local code=$1 line=$2 cmd=$3 src=${4:-${BASH_SOURCE[1]}}
  printf '\n  %s✖ HATA%s %s satir %s: komut basarisiz (cikis kodu %s)\n' \
    "$C_RED$C_BOLD" "$C_RESET" "${src##*/}" "$line" "$code" >&2
  printf '    %s%s%s\n\n' "$C_DIM" "$cmd" "$C_RESET" >&2
}

# ---------------------------------------------------------------------------
# Kontrol tablosu (preflight icin)
# ---------------------------------------------------------------------------

CHECK_OK_COUNT=0
CHECK_WARN_COUNT=0
CHECK_FAIL_COUNT=0

# table_header: kontrol tablosunun basligi.
table_header() {
  printf '  %s%s %s %s %s%s\n' "$C_BOLD" \
    "$(pad "DURUM" 9)" "$(pad "KONTROL" 26)" "$(pad "BEKLENEN" 22)" "BULUNAN" "$C_RESET"
  hr
}

# check_row <ok|warn|fail> <kontrol> <beklenen> <bulunan>: tek satirlik sonuc.
# Sayaclari da gunceller, boylece ozet otomatik cikar.
check_row() {
  local status=$1 label=$2 expected=$3 found=$4
  local tag color
  case "$status" in
    ok)
      tag="[ TAMAM ]" color=$C_GREEN
      CHECK_OK_COUNT=$((CHECK_OK_COUNT + 1))
      ;;
    warn)
      tag="[ UYARI ]" color=$C_YELLOW
      CHECK_WARN_COUNT=$((CHECK_WARN_COUNT + 1))
      ;;
    fail)
      tag="[ HATA  ]" color=$C_RED
      CHECK_FAIL_COUNT=$((CHECK_FAIL_COUNT + 1))
      ;;
    *)
      tag="[  ??   ]" color=$C_DIM
      ;;
  esac
  printf '  %s%s%s %s %s %s\n' \
    "$color" "$tag" "$C_RESET" "$(pad "$label" 26)" "$(pad "$expected" 22)" "$found"
}

# check_note: bir kontrol satirinin altina aciklama/cozum onerisi.
check_note() {
  printf '            %s↳ %s%s\n' "$C_DIM" "$1" "$C_RESET"
}

# ---------------------------------------------------------------------------
# Komut ve onay yardimcilari
# ---------------------------------------------------------------------------

# has_cmd <komut>: PATH icinde var mi?
has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# require_cmd <komut> [aciklama]: yoksa oldurucu hata.
require_cmd() {
  local cmd=$1 hint=${2:-}
  if ! has_cmd "$cmd"; then
    log_err "'$cmd' komutu bulunamadi."
    [[ -n $hint ]] && log_dim "$hint"
    exit 1
  fi
}

# confirm <soru>: varsayilan HAYIR. ASSUME_YES=1 ise sormadan gecer.
confirm() {
  local question=$1 answer
  if [[ ${ASSUME_YES:-0} == "1" ]]; then
    log_info "$question -> otomatik onay (--yes)"
    return 0
  fi
  if ! is_tty; then
    log_warn "Terminal etkilesimli degil, onay alinamadi. --yes kullanin."
    return 1
  fi
  printf '  %s?%s %s %s[e/H]%s ' "$C_YELLOW" "$C_RESET" "$question" "$C_DIM" "$C_RESET"
  read -r answer
  [[ $answer =~ ^([eEyY]|[eE][vV][eE][tT]|[yY][eE][sS])$ ]]
}

# ---------------------------------------------------------------------------
# Boyut yardimcilari
# ---------------------------------------------------------------------------

# to_mib <boyut>: 4G / 512M / 2.5G / 10240 (bayt) girdisini MiB'e cevirir.
# Coklu birim kabul eder: K/KB/KiB, M/MB/MiB, G/GB/GiB, T/TB/TiB.
to_mib() {
  local raw=${1:-0} num unit
  num=${raw//[!0-9.]/}
  unit=${raw//[0-9. ]/}
  unit=${unit^^}
  [[ -z $num ]] && {
    printf '0'
    return 0
  }
  # Carpanlar MiB cinsinden; birimsiz girdi bayt kabul edilir (multipass davranisi).
  local factor
  case "$unit" in
    K | KB | KIB) factor=0.0009765625 ;;
    M | MB | MIB) factor=1 ;;
    G | GB | GIB) factor=1024 ;;
    T | TB | TIB) factor=1048576 ;;
    "") factor=0.00000095367431640625 ;;
    *) factor=1 ;;
  esac
  awk -v n="$num" -v f="$factor" 'BEGIN { printf "%d", (n * f) + 0.5 }'
}

# fmt_mib <mib>: MiB degerini okunur metne cevirir (ornek: 12288 -> "12.0 GiB").
fmt_mib() {
  local mib=${1:-0}
  awk -v m="$mib" 'BEGIN {
    if (m >= 1024) printf "%.1f GiB", m / 1024
    else printf "%d MiB", m
  }'
}

# ---------------------------------------------------------------------------
# Spinner
# ---------------------------------------------------------------------------

# with_spinner <mesaj> <komut...>: komutu arka planda calistirir, ilerleme
# gostergesi ve gecen sureyi basar. Komut basarisiz olursa ciktiyi gosterir.
#
# SPINNER_STDIN=<dosya> tanimliysa komutun standart girdisi o dosyadan beslenir.
with_spinner() {
  local msg=$1
  shift
  local logfile stdin_src
  logfile=$(mktemp -t spinner.XXXXXX)
  stdin_src=${SPINNER_STDIN:-/dev/null}

  if ! is_tty; then
    printf '  %s·%s %s ...\n' "$C_CYAN" "$C_RESET" "$msg"
    if "$@" <"$stdin_src" >"$logfile" 2>&1; then
      log_ok "$msg"
      rm -f "$logfile"
      return 0
    fi
    log_err "$msg - basarisiz"
    sed 's/^/      /' "$logfile" >&2
    rm -f "$logfile"
    return 1
  fi

  "$@" <"$stdin_src" >"$logfile" 2>&1 &
  local pid=$!
  # Dizi kullaniliyor: cok baytli karakterlerde substring locale'e bagimli olurdu.
  local frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  local i=0 start elapsed
  start=$SECONDS
  # Imleci gizle, cikista geri ac.
  printf '\033[?25l'
  while kill -0 "$pid" 2>/dev/null; do
    elapsed=$((SECONDS - start))
    printf '\r  %s%s%s %s %s(%ss)%s ' \
      "$C_CYAN" "${frames[i++ % 10]}" "$C_RESET" "$msg" "$C_DIM" "$elapsed" "$C_RESET"
    sleep 0.1
  done
  printf '\033[?25h\r\033[K'

  local rc=0
  wait "$pid" || rc=$?
  elapsed=$((SECONDS - start))
  if ((rc == 0)); then
    printf '  %s✔%s %s %s(%ss)%s\n' "$C_GREEN" "$C_RESET" "$msg" "$C_DIM" "$elapsed" "$C_RESET"
    rm -f "$logfile"
    return 0
  fi

  printf '  %s✖%s %s %s(%ss, cikis kodu %s)%s\n' \
    "$C_RED" "$C_RESET" "$msg" "$C_DIM" "$elapsed" "$rc" "$C_RESET" >&2
  sed 's/^/      /' "$logfile" >&2
  rm -f "$logfile"
  return "$rc"
}
