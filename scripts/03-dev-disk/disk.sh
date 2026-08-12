#!/usr/bin/env bash
#
# disk.sh - Gelistirme makinesinde biriken copu olcer ve temizler.
#
# GUVENLIK ILKESI
#   Varsayilan temizlik yalnizca YENIDEN URETILEBILIR seyleri siler:
#     docker build cache, sarkan (dangling) imajlar, apt onbellegi,
#     eski snap surumleri, eski journal kayitlari, cop kutusu.
#
#   Asla dokunulmayanlar:
#     * Docker volume'lari  -> icinde veritabani/uygulama verisi olabilir.
#                              Yalnizca raporlanir, silme komutu kullaniciya birakilir.
#     * Konteynerler        -> durmus olanlar bile kullanicinin isine yarayabilir.
#     * Kullanilan imajlar  -> calisan konteynerlerin imajlari.
#
#   --aggressive ile ek olarak KULLANILMAYAN imajlar da silinir; bu, yerel
#   olarak build edilmis imajlarin yeniden build edilmesini gerektirir.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh disable=SC1091
source "${REPO_ROOT}/lib/common.sh"
enable_error_trap

MODE="report"
AGGRESSIVE=0
DRY_RUN=0
SKIP_SUDO=0
JOURNAL_KEEP="7d"
SNAP_RETAIN=2

usage() {
  cat <<'EOF'
Kullanim: disk.sh [SECENEKLER]

Secenekler:
  --mode <report|clean>    report: sadece olcer (varsayilan), clean: temizler
  --aggressive             Kullanilmayan docker imajlarini da siler
  --dry-run                Hicbir sey silmez, ne yapilacagini gosterir
  --skip-sudo              sudo gerektiren adimlari atlar (apt, snap, journal)
  --journal-keep <sure>    journald icin saklanacak sure (varsayilan: 7d)
  --snap-retain <n>        snap icin saklanacak surum sayisi (varsayilan: 2)
  --yes                    Onay sorularini atlar
  --no-color               Renkli ciktiyi kapatir
  -h, --help               Bu yardimi gosterir

Ornekler:
  ./disk.sh                        # ne kadar cop var?
  ./disk.sh --mode clean           # guvenli temizlik
  ./disk.sh --mode clean --dry-run # ne silinecegini gor, silme
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --aggressive)
      AGGRESSIVE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --skip-sudo)
      SKIP_SUDO=1
      shift
      ;;
    --journal-keep)
      JOURNAL_KEEP="$2"
      shift 2
      ;;
    --snap-retain)
      SNAP_RETAIN="$2"
      shift 2
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

# --- Olcum yardimcilari ----------------------------------------------------

# to_mib_human <metin>: "3.594GB", "347.1M", "28.67kB" gibi degerleri MiB'e cevirir.
to_mib_human() {
  local raw="${1:-0}"
  raw="${raw%% *}" # "2.482GB (31%)" -> "2.482GB"
  awk -v s="$raw" 'BEGIN {
    n = s + 0
    u = toupper(s)
    if (u ~ /[0-9.]+ *T/) n *= 1024 * 1024
    else if (u ~ /[0-9.]+ *G/) n *= 1024
    else if (u ~ /[0-9.]+ *M/) n *= 1
    else if (u ~ /[0-9.]+ *K/) n /= 1024
    else n /= 1048576
    printf "%d", n + 0.5
  }'
}

# dir_mib <dizin>: dizin boyutu (MiB). Okunamiyorsa veya yoksa 0.
dir_mib() {
  local d=$1 out
  if [[ ! -d $d ]]; then
    printf '0'
    return 0
  fi
  # Izin reddi durumunda du bos doner; aritmetikte kullanildigi icin
  # her halukarda sayisal bir deger basmak zorundayiz.
  out="$(du -sm "$d" 2>/dev/null | awk '{print $1+0; exit}' || true)"
  printf '%s' "${out:-0}"
}

# docker_df <TYPE>: `docker system df` satirindan geri kazanilabilir MiB.
docker_df_reclaimable() {
  local type=$1 line
  line="$(docker system df --format '{{.Type}}|{{.Reclaimable}}' 2>/dev/null |
    awk -F'|' -v t="$type" '$1 == t {print $2; exit}' || true)"
  to_mib_human "${line:-0}"
}

have_sudo() {
  ((SKIP_SUDO == 0)) && has_cmd sudo
}

# --- Kategori olcumleri ----------------------------------------------------
# Her olcum iki global yazar: <AD>_MIB ve <AD>_NOTE

BUILD_CACHE_MIB=0
DANGLING_MIB=0
UNUSED_IMG_MIB=0
VOLUME_MIB=0
JOURNAL_MIB=0
APT_MIB=0
SNAP_MIB=0
TRASH_MIB=0
SNAP_OLD_LIST=""

measure_docker() {
  has_cmd docker || return 0
  docker info >/dev/null 2>&1 || return 0

  BUILD_CACHE_MIB="$(docker_df_reclaimable "Build Cache")"
  UNUSED_IMG_MIB="$(docker_df_reclaimable "Images")"
  VOLUME_MIB="$(docker_df_reclaimable "Local Volumes")"

  # Sarkan imajlar kullanilmayan imajlarin alt kumesidir; ayrica olculur.
  # Her satir "123MB" gibi kendi birimini tasidigi icin tek tek cevrilmeli.
  local size
  DANGLING_MIB=0
  while read -r size; do
    [[ -z ${size:-} ]] && continue
    DANGLING_MIB=$((DANGLING_MIB + $(to_mib_human "$size")))
  done < <(docker images -f dangling=true --format '{{.Size}}' 2>/dev/null || true)
}

measure_system() {
  local ju
  ju="$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[KMGT]' | tail -1 || true)"
  JOURNAL_MIB="$(to_mib_human "${ju:-0}")"

  APT_MIB="$(dir_mib /var/cache/apt/archives)"

  if has_cmd snap; then
    SNAP_OLD_LIST="$(snap list --all 2>/dev/null | awk '/disabled/ {print $1 " " $3}' || true)"
    local rev name
    SNAP_MIB=0
    while read -r name rev; do
      [[ -z ${name:-} ]] && continue
      local f="/var/lib/snapd/snaps/${name}_${rev}.snap"
      if [[ -f $f ]]; then
        SNAP_MIB=$((SNAP_MIB + $(du -sm "$f" 2>/dev/null | awk '{print $1+0}')))
      fi
    done <<<"$SNAP_OLD_LIST"
  fi

  TRASH_MIB="$(dir_mib "${HOME}/.local/share/Trash")"
}

# --- Rapor -----------------------------------------------------------------

row() {
  local label=$1 mib=$2 note=$3 color=$C_GREEN
  ((mib == 0)) && color=$C_DIM
  printf '  %s %s%s%s %s\n' \
    "$(pad "$label" 26)" "$color" "$(pad "$(fmt_mib "$mib")" 12)" "$C_RESET" "$note"
}

print_report() {
  local safe_total=$((BUILD_CACHE_MIB + DANGLING_MIB + JOURNAL_MIB + APT_MIB + SNAP_MIB + TRASH_MIB))
  local aggressive_total=$((safe_total + UNUSED_IMG_MIB - DANGLING_MIB))

  printf '  %s%s %s %s%s\n' "$C_BOLD" \
    "$(pad "KATEGORI" 26)" "$(pad "KAZANC" 12)" "NOT" "$C_RESET"
  hr

  row "Docker build cache" "$BUILD_CACHE_MIB" "guvenli - yeniden uretilir"
  row "Docker sarkan imajlar" "$DANGLING_MIB" "guvenli - etiketsiz artiklar"
  row "journald kayitlari" "$JOURNAL_MIB" "${JOURNAL_KEEP} oncesi silinir"
  row "APT paket onbellegi" "$APT_MIB" "guvenli - yeniden indirilir"
  row "Eski snap surumleri" "$SNAP_MIB" "guvenli - son ${SNAP_RETAIN} surum kalir"
  row "Cop kutusu" "$TRASH_MIB" "guvenli"
  hr
  printf '  %s%s %s%s%s  guvenli temizlik\n' "$C_BOLD" \
    "$(pad "TOPLAM" 26)" "$C_GREEN" "$(pad "$(fmt_mib "$safe_total")" 12)" "$C_RESET"

  printf '\n  %sAyri degerlendirilenler%s\n' "$C_BOLD" "$C_RESET"
  hr
  row "Kullanilmayan imajlar" "$UNUSED_IMG_MIB" "${C_YELLOW}yeniden build gerekir${C_RESET}"
  printf '  %s %s%s%s %s\n' \
    "$(pad "Sarkan volume'lar" 26)" "$C_RED" "$(pad "$(fmt_mib "$VOLUME_MIB")" 12)" "$C_RESET" \
    "${C_RED}VERI KAYBI RISKI - silinmez${C_RESET}"
  hr
  printf '  %s%s %s%s%s  disk-clean-all ile\n\n' "$C_BOLD" \
    "$(pad "TOPLAM" 26)" "$C_YELLOW" "$(pad "$(fmt_mib "$aggressive_total")" 12)" "$C_RESET"

  if ((VOLUME_MIB > 0)); then
    log_warn "Sarkan volume'lar bu script tarafindan ASLA silinmez."
    log_dim "Icerigini kontrol edip kendiniz karar verin:"
    log_cmd "docker volume ls -f dangling=true"
    log_cmd "docker volume inspect <ad> | head -20"
    log_dim "Eminseniz: docker volume prune   (geri donusu yoktur)"
    printf '\n'
  fi

  printf '  %sDisk durumu%s\n' "$C_BOLD" "$C_RESET"
  df -h / | sed 's/^/    /'
  printf '\n'
}

# --- Temizlik --------------------------------------------------------------

# run_step <aciklama> <komut...>: dry-run modunda yalnizca komutu yazar.
run_step() {
  local desc=$1
  shift
  if ((DRY_RUN == 1)); then
    printf '  %s[kuru]%s %s\n' "$C_DIM" "$C_RESET" "$desc"
    log_dim "$*"
    return 0
  fi
  with_spinner "$desc" "$@" || log_warn "${desc} - basarisiz, atlandi"
}

clean_docker() {
  has_cmd docker || return 0
  docker info >/dev/null 2>&1 || {
    log_warn "Docker calismiyor, docker adimlari atlandi."
    return 0
  }

  log_step "Docker"
  run_step "Build cache temizleniyor" docker builder prune -f
  run_step "Sarkan imajlar temizleniyor" docker image prune -f

  if ((AGGRESSIVE == 1)); then
    log_warn "Kullanilmayan TUM imajlar siliniyor (yerel build'ler dahil)."
    run_step "Kullanilmayan imajlar temizleniyor" docker image prune -a -f
  fi
}

clean_system() {
  if ! have_sudo; then
    log_step "Sistem (atlandi)"
    log_info "sudo adimlari atlandi (--skip-sudo veya sudo yok)."
    log_dim "Elle: sudo apt-get clean · sudo journalctl --vacuum-time=${JOURNAL_KEEP}"
    return 0
  fi

  log_step "Sistem (sudo gerekir)"

  if has_cmd apt-get; then
    run_step "APT onbellegi temizleniyor" sudo apt-get clean
  fi

  if has_cmd journalctl; then
    run_step "journald ${JOURNAL_KEEP} oncesine kadar kirpiliyor" \
      sudo journalctl --vacuum-time="$JOURNAL_KEEP"
  fi

  if has_cmd snap && [[ -n $SNAP_OLD_LIST ]]; then
    run_step "snap saklanacak surum sayisi ${SNAP_RETAIN}" \
      sudo snap set system refresh.retain="$SNAP_RETAIN"
    local name rev
    while read -r name rev; do
      [[ -z ${name:-} ]] && continue
      run_step "Eski snap siliniyor: ${name} (rev ${rev})" \
        sudo snap remove "$name" --revision="$rev"
    done <<<"$SNAP_OLD_LIST"
  fi
}

clean_trash() {
  local trash="${HOME}/.local/share/Trash"
  [[ -d $trash ]] || return 0
  ((TRASH_MIB > 0)) || return 0

  log_step "Cop kutusu"
  if ((DRY_RUN == 1)); then
    printf '  %s[kuru]%s Cop kutusu bosaltilacak (%s)\n' \
      "$C_DIM" "$C_RESET" "$(fmt_mib "$TRASH_MIB")"
    return 0
  fi
  rm -rf "${trash:?}/files/"* "${trash:?}/info/"* 2>/dev/null || true
  log_ok "Cop kutusu bosaltildi"
}

# --- Akis ------------------------------------------------------------------

measure_docker
measure_system

case "$MODE" in
  report)
    banner "Disk raporu" "gelistirme makinesinde biriken cop"
    print_report
    log_info "Temizlemek icin: make disk-clean   (once denemek icin: make disk-clean DRY=1)"
    printf '\n'
    ;;

  clean)
    CLEAN_TITLE="Guvenli temizlik"
    ((AGGRESSIVE == 1)) && CLEAN_TITLE="Genis temizlik (kullanilmayan imajlar dahil)"
    if ((DRY_RUN == 1)); then
      CLEAN_SUBTITLE="kuru calisma - hicbir sey silinmez"
    else
      CLEAN_SUBTITLE="silinen geri gelmez"
    fi
    banner "$CLEAN_TITLE" "$CLEAN_SUBTITLE"

    print_report

    if ((DRY_RUN == 0)); then
      if ((AGGRESSIVE == 1)); then
        log_warn "Yerel build edilmis imajlar (ornegin kendi projeleriniz) da silinecek."
        log_warn "Bunlar yeniden build edilmeli; internetten gelenler yeniden indirilir."
      fi
      if ! confirm "Temizlik baslatilsin mi?"; then
        log_info "Iptal edildi, hicbir sey silinmedi."
        printf '\n'
        exit 0
      fi
    fi

    clean_docker
    clean_system
    clean_trash

    if ((DRY_RUN == 1)); then
      printf '\n'
      log_info "Kuru calismaydi, hicbir sey silinmedi."
      log_dim "Gercekten calistirmak icin DRY=1 olmadan tekrar deneyin."
      printf '\n'
      exit 0
    fi

    log_step "Sonuc"
    measure_docker
    measure_system
    print_report
    ;;

  *)
    die "Gecersiz mod: ${MODE} (report veya clean olmali)"
    ;;
esac
