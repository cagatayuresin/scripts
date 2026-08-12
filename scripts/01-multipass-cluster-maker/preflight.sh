#!/usr/bin/env bash
#
# preflight.sh - Multipass lab kurulmadan once sistemin hazir olup olmadigini denetler.
#
# `make cluster` ve `make singlenode` bu scripti zorunlu on kosul olarak calistirir.
# Hicbir sey kurmaz, hicbir seyi degistirmez: sadece okur ve rapor eder.
#
# Cikis kodlari:
#   0 - sistem hazir (yalnizca uyari varsa da 0 doner, uyarilar ekranda listelenir)
#   1 - en az bir engelleyici eksik var (--force ile gecilebilir)

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh disable=SC1091
source "${REPO_ROOT}/lib/common.sh"
enable_error_trap

# --- Varsayilanlar ---------------------------------------------------------
PROFILE="cluster"
NODES="master worker datanode"
CPUS="2"
MEMORY="4G"
DISK="10G"
RELEASE="24.04"
FORCE=0

# Gereken en dusuk multipass surumu (--cloud-init ve --disk destegi icin)
MIN_MULTIPASS_VERSION="1.10.0"
# Ubuntu imajinin indirilmesi/genislemesi icin ayrilan pay (MiB)
IMAGE_OVERHEAD_MIB=3072
# Host icin bos birakilmasi istenen bellek payi (MiB)
HOST_MEMORY_RESERVE_MIB=1024

usage() {
  cat <<'EOF'
Kullanim: preflight.sh [SECENEKLER]

Secenekler:
  --profile <cluster|singlenode>  Denetlenecek senaryo (varsayilan: cluster)
  --nodes "<ad1 ad2 ...>"         Kurulacak makine adlari
  --cpus <n>                      Makine basina vCPU (varsayilan: 2)
  --memory <boyut>                Makine basina RAM, ornek 4G (varsayilan: 4G)
  --disk <boyut>                  Makine basina disk, ornek 10G (varsayilan: 10G)
  --release <surum>               Ubuntu surumu (varsayilan: 24.04)
  --user <ad> / --pass <parola>   vm-up.sh ile ortak arayuz icin kabul edilir
  --force                         Engelleyici eksiklere ragmen 0 don
  --no-color                      Renkli ciktiyi kapat
  -h, --help                      Bu yardimi goster

Ornekler:
  ./preflight.sh --profile singlenode
  ./preflight.sh --profile cluster --cpus 4 --memory 8G --disk 20G
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
    --user | --pass)
      shift 2
      ;; # vm-up.sh ile ayni arayuz; burada kullanilmaz
    --force)
      FORCE=1
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
NODE_COUNT=${#NODE_LIST[@]}
((NODE_COUNT > 0)) || die "En az bir makine adi gerekli (--nodes)"

MEM_PER_NODE_MIB=$(to_mib "$MEMORY")
DISK_PER_NODE_MIB=$(to_mib "$DISK")
TOTAL_VCPU=$((CPUS * NODE_COUNT))
TOTAL_MEM_MIB=$((MEM_PER_NODE_MIB * NODE_COUNT))
TOTAL_DISK_MIB=$((DISK_PER_NODE_MIB * NODE_COUNT + IMAGE_OVERHEAD_MIB))

# --- Yardimcilar -----------------------------------------------------------

# version_ge <a> <b>: a >= b mi? (1.16.3 vs 1.10.0)
version_ge() {
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]
}

# multipass_storage_path: makine imajlarinin tutuldugu dizin.
multipass_storage_path() {
  local candidates=(
    "${MULTIPASS_STORAGE:-}"
    "/var/snap/multipass/common/data/multipassd"
    "/var/snap/multipass/common"
    "/var/lib/multipass"
  )
  local path
  for path in "${candidates[@]}"; do
    [[ -n $path && -d $path ]] && {
      printf '%s' "$path"
      return 0
    }
  done
  printf '/'
}

# --- Kontroller ------------------------------------------------------------

check_tools() {
  local mp_version=""

  if has_cmd multipass; then
    mp_version="$(multipass version 2>/dev/null | awk '/^multipass/ {print $2; exit}')"
    mp_version="${mp_version:-bilinmiyor}"
    if [[ $mp_version != "bilinmiyor" ]] && version_ge "$mp_version" "$MIN_MULTIPASS_VERSION"; then
      check_row ok "Multipass istemcisi" ">= ${MIN_MULTIPASS_VERSION}" "$mp_version"
    else
      check_row warn "Multipass istemcisi" ">= ${MIN_MULTIPASS_VERSION}" "$mp_version"
      check_note "Eski surumlerde --cloud-init/--disk destegi eksik olabilir."
    fi
  else
    check_row fail "Multipass istemcisi" "kurulu" "bulunamadi"
    check_note "Kurulum icin: make install-deps  (veya: sudo snap install multipass)"
    return 0
  fi

  # Daemon (multipassd) gercekten cevap veriyor mu?
  local daemon_version=""
  daemon_version="$(multipass version 2>/dev/null | awk '/^multipassd/ {print $2; exit}')"
  if [[ -n $daemon_version ]]; then
    check_row ok "Multipass servisi" "calisiyor" "multipassd ${daemon_version}"
  else
    check_row fail "Multipass servisi" "calisiyor" "yanit yok"
    check_note "Servisi baslatin: sudo snap start multipass  (durum: snap services multipass)"
  fi

  local driver=""
  driver="$(multipass get local.driver 2>/dev/null || true)"
  if [[ -n $driver ]]; then
    check_row ok "Sanallastirma surucusu" "qemu/libvirt" "$driver"
  else
    check_row warn "Sanallastirma surucusu" "qemu/libvirt" "okunamadi"
  fi

  # Yardimci araclar
  local tool
  for tool in awk sed grep; do
    if has_cmd "$tool"; then
      check_row ok "Arac: ${tool}" "kurulu" "var"
    else
      check_row fail "Arac: ${tool}" "kurulu" "yok"
    fi
  done

  if has_cmd ssh; then
    check_row ok "SSH istemcisi" "kurulu" "var"
  else
    check_row warn "SSH istemcisi" "kurulu" "yok"
    check_note "Makinelere baglanmak icin: sudo apt install openssh-client"
  fi

  if has_cmd sshpass; then
    check_row ok "sshpass (opsiyonel)" "kurulu" "var"
  else
    check_row warn "sshpass (opsiyonel)" "kurulu" "yok"
    check_note "Kurulursa parola ile SSH girisi kurulum sonunda otomatik dogrulanir."
  fi
}

check_virtualization() {
  if [[ -e /dev/kvm ]]; then
    if [[ -r /dev/kvm && -w /dev/kvm ]]; then
      check_row ok "KVM cihazi" "okunur/yazilir" "/dev/kvm"
    else
      # Multipass snap'i kendi servis kullanicisiyla eristigi icin bu cogu zaman
      # engelleyici degildir; yine de bilgi verilir.
      check_row warn "KVM cihazi" "okunur/yazilir" "izin yok"
      check_note "Gerekirse: sudo usermod -aG kvm \$USER  (sonrasinda yeniden oturum acin)"
    fi
  else
    check_row fail "KVM cihazi" "/dev/kvm mevcut" "yok"
    check_note "BIOS/UEFI'de sanallastirma (VT-x/AMD-V) kapali olabilir."
  fi

  local flags=""
  flags="$(grep -m1 -o -E '\b(vmx|svm)\b' /proc/cpuinfo 2>/dev/null || true)"
  if [[ -n $flags ]]; then
    check_row ok "CPU sanallastirma" "vmx veya svm" "$flags"
  else
    check_row fail "CPU sanallastirma" "vmx veya svm" "destek yok"
  fi
}

check_cpu() {
  local host_cores
  host_cores="$(nproc)"
  local soft_limit=$((host_cores * 3 / 2))

  if ((TOTAL_VCPU <= host_cores)); then
    check_row ok "CPU cekirdegi" "${TOTAL_VCPU} vCPU" "${host_cores} cekirdek"
  elif ((TOTAL_VCPU <= soft_limit)); then
    check_row warn "CPU cekirdegi" "${TOTAL_VCPU} vCPU" "${host_cores} cekirdek"
    check_note "Cekirdek sayisi asiliyor (overcommit); makineler yavas calisabilir."
  else
    check_row fail "CPU cekirdegi" "${TOTAL_VCPU} vCPU" "${host_cores} cekirdek"
    check_note "CPUS degerini dusurun: make ${PROFILE} CPUS=1"
  fi
}

check_memory() {
  local total_mib avail_mib
  total_mib="$(awk '/^MemTotal:/ {printf "%d", $2/1024}' /proc/meminfo)"
  avail_mib="$(awk '/^MemAvailable:/ {printf "%d", $2/1024}' /proc/meminfo)"
  local needed=$((TOTAL_MEM_MIB + HOST_MEMORY_RESERVE_MIB))

  if ((avail_mib >= needed)); then
    check_row ok "Kullanilabilir bellek" ">= $(fmt_mib "$needed")" "$(fmt_mib "$avail_mib")"
  elif ((total_mib >= needed)); then
    check_row warn "Kullanilabilir bellek" ">= $(fmt_mib "$needed")" "$(fmt_mib "$avail_mib")"
    check_note "Toplam RAM yeterli ($(fmt_mib "$total_mib")) ama su an dolu; uygulama kapatmayi dusunun."
  else
    check_row fail "Kullanilabilir bellek" ">= $(fmt_mib "$needed")" "toplam $(fmt_mib "$total_mib")"
    check_note "MEMORY degerini dusurun: make ${PROFILE} MEMORY=2G"
  fi
}

check_disk() {
  local storage avail_mib
  storage="$(multipass_storage_path)"
  avail_mib="$(df -BM --output=avail "$storage" 2>/dev/null | tail -n1 | tr -dc '0-9')"
  avail_mib="${avail_mib:-0}"

  if ((avail_mib >= TOTAL_DISK_MIB)); then
    check_row ok "Bos disk alani" ">= $(fmt_mib "$TOTAL_DISK_MIB")" "$(fmt_mib "$avail_mib")"
  elif ((avail_mib >= TOTAL_DISK_MIB / 2)); then
    check_row warn "Bos disk alani" ">= $(fmt_mib "$TOTAL_DISK_MIB")" "$(fmt_mib "$avail_mib")"
    check_note "Disk imajlari seyrek (sparse) buyudugu icin baslangicta yetebilir."
  else
    check_row fail "Bos disk alani" ">= $(fmt_mib "$TOTAL_DISK_MIB")" "$(fmt_mib "$avail_mib")"
    check_note "DISK degerini dusurun: make ${PROFILE} DISK=5G"
  fi
  check_note "Olculen dizin: ${storage}"
}

check_image() {
  has_cmd multipass || return 0

  # CSV basliklari: Image,Remote,Aliases,OS,Release,Version,Type
  local found=""
  found="$(multipass find --format csv 2>/dev/null | awk -F, -v r="$RELEASE" \
    'NR>1 && ($1 == r || index($3, r) > 0) {print $1; exit}' || true)"

  if [[ -n $found ]]; then
    check_row ok "Ubuntu imaji" "$RELEASE" "kullanilabilir"
  else
    check_row warn "Ubuntu imaji" "$RELEASE" "listede bulunamadi"
    check_note "Ag baglantisi yoksa veya surum adi yanlissa olusur. Liste: multipass find"
  fi
}

check_name_conflicts() {
  has_cmd multipass || return 0

  local existing node conflicts=()
  existing="$(multipass list --format csv 2>/dev/null | awk -F, 'NR>1 {print $1}' || true)"
  for node in "${NODE_LIST[@]}"; do
    if grep -qx -- "$node" <<<"$existing"; then
      conflicts+=("$node")
    fi
  done

  if ((${#conflicts[@]} == 0)); then
    check_row ok "Makine adi cakismasi" "yok" "temiz"
  else
    check_row warn "Makine adi cakismasi" "yok" "${conflicts[*]}"
    check_note "Mevcut makineler atlanir. Yeniden kurmak icin: make ${PROFILE} RECREATE=1"
    check_note "Tamamen silmek icin: make clean"
  fi
}

# --- Rapor -----------------------------------------------------------------

print_plan() {
  banner "Preflight - sistem gereksinim denetimi" "profil: ${PROFILE}"
  printf '  %sKurulacak makineler%s : %s\n' "$C_BOLD" "$C_RESET" "${NODE_LIST[*]}"
  printf '  %sMakine basina%s       : %s vCPU, %s RAM, %s disk (Ubuntu %s)\n' \
    "$C_BOLD" "$C_RESET" "$CPUS" "$MEMORY" "$DISK" "$RELEASE"
  printf '  %sToplam ihtiyac%s      : %s vCPU, %s RAM, %s disk (imaj payi dahil)\n\n' \
    "$C_BOLD" "$C_RESET" "$TOTAL_VCPU" "$(fmt_mib "$TOTAL_MEM_MIB")" "$(fmt_mib "$TOTAL_DISK_MIB")"
}

print_summary() {
  hr
  printf '  Sonuc: %s%d tamam%s, %s%d uyari%s, %s%d hata%s\n' \
    "$C_GREEN" "$CHECK_OK_COUNT" "$C_RESET" \
    "$C_YELLOW" "$CHECK_WARN_COUNT" "$C_RESET" \
    "$C_RED" "$CHECK_FAIL_COUNT" "$C_RESET"

  if ((CHECK_FAIL_COUNT > 0)); then
    if ((FORCE == 1)); then
      printf '\n  %s⚠ FORCE=1 verildi: engelleyici eksiklere ragmen devam ediliyor.%s\n\n' \
        "$C_YELLOW$C_BOLD" "$C_RESET"
      return 0
    fi
    printf '\n  %s✖ Sistem hazir degil.%s Yukaridaki %d engeli giderip tekrar deneyin.\n' \
      "$C_RED$C_BOLD" "$C_RESET" "$CHECK_FAIL_COUNT"
    printf '    Eksik paketleri kurmak icin : %smake install-deps%s\n' "$C_MAGENTA" "$C_RESET"
    printf '    Yine de denemek icin        : %smake %s FORCE=1%s\n\n' "$C_MAGENTA" "$PROFILE" "$C_RESET"
    return 1
  fi

  if ((CHECK_WARN_COUNT > 0)); then
    printf '\n  %s⚠ Sistem hazir, ancak %d uyari var.%s Kuruluma devam edilebilir.\n\n' \
      "$C_YELLOW$C_BOLD" "$CHECK_WARN_COUNT" "$C_RESET"
  else
    printf '\n  %s✔ Sistem hazir.%s Kuruluma gecebilirsiniz.\n\n' "$C_GREEN$C_BOLD" "$C_RESET"
  fi
  return 0
}

main() {
  print_plan
  table_header
  check_tools
  check_virtualization
  check_cpu
  check_memory
  check_disk
  check_image
  check_name_conflicts
  # `|| exit` kullaniliyor: dogrudan cagrilsaydi ERR trap gereksiz yere tetiklenirdi.
  print_summary || exit 1
}

main "$@"
