#!/usr/bin/env bash
#
# models.sh - Ollama model envanteri ve GERCEK disk kullanimi.
#
# `ollama list` her modelin yanina kendi boyutunu yazar; ancak ayni temel
# modelin varyantlari (ornegin gpt-oss:20b, :20b-32k, :20b-64k) diskteki ayni
# katmanlari (blob) paylasir. Bu yuzden listelenen boyutlarin toplami gercek
# disk kullanimindan cok daha buyuk gorunur ve "bir varyanti silersem yer
# kazanirim" yanilgisina yol acar.
#
# --mode disk, manifest dosyalarini okuyup katmanlari benzersizlestirir:
#   * diskte gercekten ne kadar yer kaplandigini,
#   * bir modeli silmenin ne kadar yer kazandiracagini (cogu zaman sifir),
#   * ayni katmanlari paylasan model ailelerini gosterir.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh disable=SC1091
source "${REPO_ROOT}/lib/common.sh"
enable_error_trap

MODE="list"
HOST="http://localhost:11434"
TARGET_MODELS=""
RM_ALL=0
DRY_RUN=0

# Cloud modellerin manifesti yalnizca birkac yuz bayttir; yerel modelden bu
# esikle ayrilir.
CLOUD_SIZE_LIMIT=1000000

usage() {
  cat <<'EOF'
Kullanim: models.sh [SECENEKLER]

Secenekler:
  --mode <list|disk|rm>  list: envanter, disk: gercek disk analizi, rm: model silme
  --host <url>           Ollama adresi (varsayilan: http://localhost:11434)
  --models "<a b c>"     rm modunda silinecek modeller
  --all                  rm modunda TUM yerel modelleri siler
  --dry-run              Hicbir sey silmez, ne silinecegini gosterir
  --yes                  Onay sorularini atlar
  --no-color             Renkli ciktiyi kapatir
  -h, --help             Bu yardimi gosterir

Ornekler:
  ./models.sh --mode disk
  ./models.sh --mode rm --models "qwen3:14b qwen3:14b-64k" --dry-run
  ./models.sh --mode rm --all
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --host)
      HOST="$2"
      shift 2
      ;;
    --models)
      TARGET_MODELS="$2"
      shift 2
      ;;
    --all)
      RM_ALL=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
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

require_cmd curl "Kurulum: sudo apt install curl"
require_cmd jq "Kurulum: sudo apt install jq"

api() {
  curl -sf -m 15 "${HOST}$1" 2>/dev/null
}

api_up() {
  api /api/version >/dev/null 2>&1
}

if ! api_up; then
  banner "Ollama" "$HOST"
  log_err "Ollama'ya ulasilamadi."
  log_dim "Servis durumu : systemctl status ollama"
  log_dim "Elle baslatma : ollama serve"
  printf '\n'
  exit 1
fi

# --- Model dizinini bul ----------------------------------------------------

find_model_dir() {
  local candidates=(
    "${OLLAMA_MODELS:-}"
    "${HOME}/.ollama/models"
    "/usr/share/ollama/.ollama/models"
    "/var/lib/ollama/models"
  )
  local d
  for d in "${candidates[@]}"; do
    if [[ -n $d && -d "${d}/manifests" ]]; then
      printf '%s' "$d"
      return 0
    fi
  done
  printf ''
}

# --- list ------------------------------------------------------------------

mode_list() {
  local version
  version="$(api /api/version | jq -r '.version // "?"')"
  banner "Ollama modelleri" "${HOST} · surum ${version}"

  local tags
  tags="$(api /api/tags)" || die "Model listesi alinamadi."

  printf '  %s%s %s %s %s%s\n' "$C_BOLD" \
    "$(pad "MODEL" 28)" "$(pad "BOYUT" 11)" "$(pad "TUR" 8)" "PARAMETRE" "$C_RESET"
  hr

  jq -r --argjson lim "$CLOUD_SIZE_LIMIT" '
    .models | sort_by(-.size)[] |
    [ .name,
      (if .size > $lim then (.size/1073741824 | . * 100 | round / 100 | tostring) + " GB" else "-" end),
      (if .size > $lim then "yerel" else "cloud" end),
      # Bazi modeller parametre sayisini ham sayi olarak bildiriyor (4000000000);
      # okunur bicime cevir.
      ((.details.parameter_size // "-") | if test("^[0-9]+$") then ((tonumber / 1000000000) | tostring) + "B" else . end)
    ] | @tsv' <<<"$tags" |
    while IFS=$'\t' read -r name size tur param; do
      local color=$C_GREEN
      [[ $tur == "cloud" ]] && color=$C_CYAN
      printf '  %s %s %s%s%s %s\n' \
        "$(pad "$name" 28)" "$(pad "$size" 11)" "$color" "$(pad "$tur" 8)" "$C_RESET" "$param"
    done
  hr

  local local_count cloud_count listed_gb
  local_count="$(jq --argjson lim "$CLOUD_SIZE_LIMIT" '[.models[] | select(.size > $lim)] | length' <<<"$tags")"
  cloud_count="$(jq --argjson lim "$CLOUD_SIZE_LIMIT" '[.models[] | select(.size <= $lim)] | length' <<<"$tags")"
  listed_gb="$(jq --argjson lim "$CLOUD_SIZE_LIMIT" '[.models[] | select(.size > $lim) | .size] | add // 0 | . / 1073741824 | . * 100 | round / 100' <<<"$tags")"

  printf '  %d yerel model (listelenen toplam %s GB) · %d cloud model\n' \
    "$local_count" "$listed_gb" "$cloud_count"
  log_dim "Cloud modeller diskte yer kaplamaz; istek aninda Ollama bulutuna gider."

  # Bellekte tutulan modeller
  local running
  running="$(api /api/ps | jq -r '.models[]?.name' 2>/dev/null || true)"
  printf '\n  %sBellekte%s\n' "$C_BOLD" "$C_RESET"
  if [[ -n $running ]]; then
    api /api/ps | jq -r '.models[] | "    \(.name)  →  \(.size_vram/1073741824 | . * 100 | round / 100) GB VRAM"'
  else
    log_dim "Su an bellekte model yok (ilk istek modeli yuklerken bekleyeceksiniz)."
  fi

  printf '\n'
  log_info "Gercek disk kullanimi icin: make llm-disk"
  printf '\n'
}

# --- Katman toplama (disk ve rm modlari ortak kullanir) --------------------

MODEL_DIR=""
LAYER_ROWS=""

# collect_layers: manifest dosyalarindan "model \t digest \t boyut" satirlarini
# uretir. Ollama bu bilgiyi API uzerinden vermedigi icin dosyalar okunur.
collect_layers() {
  MODEL_DIR="$(find_model_dir)"
  if [[ -z $MODEL_DIR ]]; then
    log_err "Model dizini bulunamadi."
    log_dim "Aranan yerler: \$OLLAMA_MODELS, ~/.ollama/models, /usr/share/ollama/.ollama/models"
    printf '\n'
    exit 1
  fi

  if [[ ! -r "${MODEL_DIR}/manifests" ]]; then
    log_err "Manifest dizini okunamiyor: ${MODEL_DIR}/manifests"
    log_dim "Ollama systemd servisi olarak calisiyorsa kullaniciniz 'ollama' grubunda olmali:"
    log_cmd "sudo usermod -aG ollama \$USER   # sonrasinda yeniden oturum acin"
    printf '\n'
    exit 1
  fi

  LAYER_ROWS="$(
    find "${MODEL_DIR}/manifests" -type f 2>/dev/null | while read -r m; do
      # NOT: burasi komut ikamesi icindeki bir alt kabuk; 'local' kullanilamaz.
      name="${m#"${MODEL_DIR}"/manifests/}"
      # registry/library/<model>/<tag> -> model:tag
      name="$(printf '%s' "$name" | awk -F/ '{print $(NF-1) ":" $NF}')"
      jq -r --arg n "$name" '.layers[]? | "\($n)\t\(.digest)\t\(.size)"' "$m" 2>/dev/null || true
    done
  )"

  [[ -n $LAYER_ROWS ]] || die "Manifest okunamadi veya hic model yok."
}

# --- disk ------------------------------------------------------------------

mode_disk() {
  banner "Ollama disk analizi" "paylasilan katmanlar cozuluyor"

  collect_layers
  log_info "Model dizini: ${MODEL_DIR}"
  local rows=$LAYER_ROWS

  printf '\n'
  awk -F'\t' -v bold="$C_BOLD" -v reset="$C_RESET" -v green="$C_GREEN" -v dim="$C_DIM" '
    {
      model[$1] = 1
      size[$2] = $3
      if (!seen[$1 SUBSEP $2]++) { refcount[$2]++ ; owns[$1 SUBSEP $2] = 1 }
      # her modelin en buyuk katmani onun "ailesini" belirler
      if ($3 + 0 > biggest[$1] + 0) { biggest[$1] = $3; family[$1] = $2 }
    }
    END {
      real = 0
      for (d in size) real += size[d]

      printf "  %s%-28s %11s %11s%s\n", bold, "MODEL", "LISTELENEN", "SILERSEN", reset
      printf "  ------------------------------------------------------------\n"

      for (m in model) {
        listed = 0; excl = 0
        for (k in owns) {
          split(k, p, SUBSEP)
          if (p[1] == m) {
            listed += size[p[2]]
            if (refcount[p[2]] == 1) excl += size[p[2]]
          }
        }
        printf "  %-28s %8.2f GB %8.2f GB\n", m, listed/1073741824, excl/1073741824
        listed_total += listed
        # aile bazinda gercek boyut
        fam = family[m]
        if (!(fam in fam_seen)) { fam_seen[fam] = 1; fam_size[fam] = size[fam] }
        fam_members[fam] = fam_members[fam] (fam_members[fam] == "" ? "" : ", ") m
      }

      printf "  ------------------------------------------------------------\n"
      printf "  %s%-28s %8.2f GB%s  <- ollama list toplami\n", bold, "LISTELENEN TOPLAM", listed_total/1073741824, reset
      printf "  %s%-28s %8.2f GB%s  <- diskte gercekten\n\n", green bold, "GERCEK DISK", real/1073741824, reset

      printf "  %sAyni katmanlari paylasan aileler%s\n", bold, reset
      printf "  ------------------------------------------------------------\n"
      for (f in fam_seen) {
        n = split(fam_members[f], a, ", ")
        if (n > 1)
          printf "  %8.2f GB  %s\n            %s(%d varyant: %s)%s\n", fam_size[f]/1073741824, "ortak katman", dim, n, fam_members[f], reset
      }
    }
  ' <<<"$rows"

  printf '\n'
  log_warn "'SILERSEN' sutunu 0.00 GB olan modelleri silmek disk kazandirmaz:"
  log_dim "katmanlari baska varyantlar da kullaniyor. Yer kazanmak icin ailenin"
  log_dim "TUM varyantlarini silmeniz gerekir."
  printf '\n  %sSilme komutu%s\n' "$C_BOLD" "$C_RESET"
  log_cmd "ollama rm <model>:<etiket>"
  printf '\n'
}

# --- rm --------------------------------------------------------------------

# freed_bytes <hedef modeller>: verilen modeller silinirse diskte gercekten
# bosalacak bayt sayisi. Bir katman yalnizca silinecek modeller tarafindan
# kullaniliyorsa bosalir; baska bir model de kullaniyorsa diskte kalir.
freed_bytes() {
  awk -F'\t' -v targets="$1" '
    BEGIN { n = split(targets, t, " "); for (i = 1; i <= n; i++) if (t[i] != "") is_target[t[i]] = 1 }
    {
      size[$2] = $3
      if (!seen[$1 SUBSEP $2]++) owners[$2] = owners[$2] " " $1
    }
    END {
      for (d in size) {
        cnt = split(owners[d], a, " ")
        kept = 0
        for (i = 1; i <= cnt; i++) if (a[i] != "" && !(a[i] in is_target)) kept = 1
        if (!kept) freed += size[d]
      }
      printf "%d", freed + 0
    }
  ' <<<"$LAYER_ROWS"
}

mode_rm() {
  local tags all_local targets=()

  tags="$(api /api/tags)" || die "Model listesi alinamadi."
  # Cloud modeller diskte yer kaplamaz; toplu silmede kapsam disi tutulur.
  all_local="$(jq -r --argjson lim "$CLOUD_SIZE_LIMIT" \
    '.models[] | select(.size > $lim) | .name' <<<"$tags")"

  if ((RM_ALL == 1)); then
    banner "TUM yerel modelleri sil" "cloud modellere dokunulmaz"
    mapfile -t targets <<<"$all_local"
  else
    [[ -n $TARGET_MODELS ]] ||
      die "Silinecek model belirtilmedi. Ornek: make llm-rm LLM_MODELS=\"qwen3:14b\" (veya make llm-purge)"
    banner "Model silme" "$TARGET_MODELS"
    read -r -a targets <<<"$TARGET_MODELS"
  fi

  ((${#targets[@]} > 0)) || {
    log_ok "Silinecek yerel model yok."
    printf '\n'
    exit 0
  }

  # Var olmayan model adlarini erkenden yakala.
  local m missing=()
  for m in "${targets[@]}"; do
    grep -qx -- "$m" <<<"$all_local" || missing+=("$m")
  done
  if ((${#missing[@]} > 0)); then
    log_err "Bu modeller kurulu degil: ${missing[*]}"
    log_dim "Kurulu modeller icin: make llm-list"
    printf '\n'
    exit 1
  fi

  collect_layers

  local freed listed=0
  freed="$(freed_bytes "${targets[*]}")"

  printf '  %s%s %s%s\n' "$C_BOLD" "$(pad "SILINECEK MODEL" 30)" "LISTELENEN" "$C_RESET"
  hr
  for m in "${targets[@]}"; do
    local sz
    sz="$(jq -r --arg n "$m" '.models[] | select(.name == $n) | .size' <<<"$tags")"
    listed=$((listed + sz))
    printf '  %s %s\n' "$(pad "$m" 30)" "$(awk -v b="$sz" 'BEGIN { printf "%.2f GB", b/1073741824 }')"
  done
  hr
  printf '  %s%s %s%s\n' "$C_BOLD" "$(pad "LISTELENEN TOPLAM" 30)" \
    "$(awk -v b="$listed" 'BEGIN { printf "%.2f GB", b/1073741824 }')" "$C_RESET"
  printf '  %s%s%s %s%s%s  %s<- diskte gercekten bosalacak%s\n\n' \
    "$C_BOLD" "$(pad "GERCEK KAZANC" 30)" "$C_RESET" \
    "$C_GREEN$C_BOLD" "$(awk -v b="$freed" 'BEGIN { printf "%.2f GB", b/1073741824 }')" "$C_RESET" \
    "$C_DIM" "$C_RESET"

  if awk -v f="$freed" -v l="$listed" 'BEGIN { exit !(f < l * 0.9) }'; then
    log_warn "Gercek kazanc listelenen boyuttan dusuk: katmanlarin bir kismini"
    log_dim "silinmeyen baska modeller de kullaniyor. Ayrinti icin: make llm-disk"
  fi

  if ((DRY_RUN == 1)); then
    log_info "Kuru calisma: hicbir model silinmedi."
    log_dim "Gercekten silmek icin DRY=1 olmadan tekrar calistirin."
    printf '\n'
    exit 0
  fi

  log_warn "Silinen modeller yeniden indirilmelidir; bu saatler surebilir."
  if ! confirm "${#targets[@]} model silinsin mi?"; then
    log_info "Iptal edildi, hicbir sey silinmedi."
    printf '\n'
    exit 0
  fi

  require_cmd ollama "Silme icin ollama komut satiri araci gerekli."
  if [[ $HOST != *"localhost"* && $HOST != *"127.0.0.1"* ]]; then
    log_warn "Uzak host belirtildi (${HOST}) ancak 'ollama rm' yerel kurulumda calisir."
  fi

  log_step "Modeller siliniyor"
  for m in "${targets[@]}"; do
    with_spinner "${m} siliniyor" ollama rm "$m" || log_err "${m} silinemedi."
  done

  log_step "Sonuc"
  local remaining
  remaining="$(api /api/tags | jq -r --argjson lim "$CLOUD_SIZE_LIMIT" \
    '[.models[] | select(.size > $lim)] | length')"
  log_ok "Kalan yerel model sayisi: ${remaining}"
  log_dim "Guncel disk durumu icin: make llm-disk"
  printf '\n'
}

case "$MODE" in
  list) mode_list ;;
  disk) mode_disk ;;
  rm) mode_rm ;;
  *) die "Gecersiz mod: ${MODE} (list, disk veya rm olmali)" ;;
esac
