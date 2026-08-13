#!/usr/bin/env bash
#
# bench.sh - Ollama saglik testi, hiz olcumu ve embedding denemesi.
#
#   --mode smoke : Ollama ayakta mi, model gercekten yanit veriyor mu
#   --mode bench : soguk baslangic, ilk token gecikmesi (TTFT), token/s
#   --mode embed : embedding ucu calisiyor mu, vektor boyutu ve gecikme
#
# Olculen degerler Ollama'nin /api/generate yanitindaki sayaclardan gelir
# (nanosaniye cinsinden): load_duration, prompt_eval_duration, eval_duration.
#
# Neden iki cagri? Ilk cagri modeli diskten belege yukler ve saniyeler surebilir;
# ikinci cagri gercek uretim hizini gosterir. LLM entegrasyonu yazarken bu iki
# sayi ayri ayri onemlidir: kullanicinin gordugu ilk gecikme ile akis hizi.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh disable=SC1091
source "${REPO_ROOT}/lib/common.sh"
enable_error_trap

MODE="smoke"
HOST="http://localhost:11434"
MODEL=""
PROMPT="Bir cumleyle kendini tanit."
TOKENS=64
CLOUD_SIZE_LIMIT=1000000

usage() {
  cat <<'EOF'
Kullanim: bench.sh [SECENEKLER]

Secenekler:
  --mode <smoke|bench|embed>  Calistirilacak test (varsayilan: smoke)
  --host <url>                Ollama adresi (varsayilan: http://localhost:11434)
  --model <ad>                Kullanilacak model (bos: otomatik secilir)
  --prompt <metin>            bench icin istem
  --tokens <n>                bench icin uretilecek token sayisi (varsayilan: 64)
  --no-color                  Renkli ciktiyi kapatir
  -h, --help                  Bu yardimi gosterir
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
    --model)
      MODEL="$2"
      shift 2
      ;;
    --prompt)
      PROMPT="$2"
      shift 2
      ;;
    --tokens)
      TOKENS="$2"
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

require_cmd curl "Kurulum: sudo apt install curl"
require_cmd jq "Kurulum: sudo apt install jq"

api_get() {
  curl -sf -m 15 "${HOST}$1" 2>/dev/null
}

api_post() {
  curl -sf -m 600 -X POST "${HOST}$1" -H 'Content-Type: application/json' -d "$2" 2>/dev/null
}

# ns_to_s <nanosaniye>: saniyeye cevirir (2 basamak).
ns_to_s() {
  awk -v n="${1:-0}" 'BEGIN { printf "%.2f", n / 1000000000 }'
}

# pick_model [embed]: uygun modeli otomatik secer.
# Cloud modeller atlanir (internet + hesap gerektirir), en kucuk yerel model secilir.
pick_model() {
  local want_embed=${1:-0} tags
  tags="$(api_get /api/tags)" || return 1
  if ((want_embed == 1)); then
    jq -r --argjson lim "$CLOUD_SIZE_LIMIT" '
      [.models[] | select(.size > $lim) | select(.name | test("embed"))] |
      sort_by(.size) | .[0].name // empty' <<<"$tags"
  else
    jq -r --argjson lim "$CLOUD_SIZE_LIMIT" '
      [.models[] | select(.size > $lim) | select(.name | test("embed") | not)] |
      sort_by(.size) | .[0].name // empty' <<<"$tags"
  fi
}

model_loaded() {
  api_get /api/ps | jq -e --arg m "$1" '.models[]? | select(.name == $m)' >/dev/null 2>&1
}

# generate <model> <prompt> <tokens>: tek uretim cagrisi, ham JSON doner.
generate() {
  local model=$1 prompt=$2 tokens=$3 payload
  payload="$(jq -n --arg m "$model" --arg p "$prompt" --argjson t "$tokens" \
    '{model: $m, prompt: $p, stream: false, options: {num_predict: $t}}')"
  api_post /api/generate "$payload"
}

# --- smoke -----------------------------------------------------------------

mode_smoke() {
  banner "Ollama saglik testi" "$HOST"
  table_header

  local version=""
  if version="$(api_get /api/version | jq -r '.version // empty')" && [[ -n $version ]]; then
    check_row ok "Ollama API" "yanit veriyor" "surum ${version}"
  else
    check_row fail "Ollama API" "yanit veriyor" "ulasilamadi"
    check_note "Servis: systemctl status ollama   ·   Elle: ollama serve"
    hr
    printf '\n'
    log_err "Ollama calismadan diger testler anlamsiz."
    printf '\n'
    exit 1
  fi

  local tags local_count
  tags="$(api_get /api/tags)"
  local_count="$(jq --argjson lim "$CLOUD_SIZE_LIMIT" '[.models[] | select(.size > $lim)] | length' <<<"$tags")"
  if ((local_count > 0)); then
    check_row ok "Yerel model" ">= 1" "${local_count} adet"
  else
    check_row warn "Yerel model" ">= 1" "yok"
    check_note "Model indirin: ollama pull qwen2.5:3b"
  fi

  [[ -n $MODEL ]] || MODEL="$(pick_model 0 || true)"
  if [[ -z $MODEL ]]; then
    check_row fail "Uretim testi" "bir yerel model" "secilemedi"
    hr
    printf '\n'
    exit 1
  fi

  # Model bellekte degilse ilk cagri yuklemeyi de kapsar; bunu kullaniciya soyle.
  local loaded="hayir"
  model_loaded "$MODEL" && loaded="evet"
  check_row ok "Secilen model" "yerel" "$MODEL"
  check_row ok "Bellekte mi" "-" "$loaded"

  local resp
  if resp="$(generate "$MODEL" "Merhaba" 8)" && [[ -n $resp ]]; then
    local text
    text="$(jq -r '.response // empty' <<<"$resp" | tr '\n' ' ' | cut -c1-40)"
    check_row ok "Uretim testi" "yanit gelmeli" "\"${text}...\""
  else
    check_row fail "Uretim testi" "yanit gelmeli" "yanit yok"
    check_note "Elle deneyin: ollama run ${MODEL} \"Merhaba\""
  fi

  local embed_model
  embed_model="$(pick_model 1 || true)"
  if [[ -n $embed_model ]]; then
    if api_post /api/embed "$(jq -n --arg m "$embed_model" '{model: $m, input: "test"}')" |
      jq -e '.embeddings[0] | length > 0' >/dev/null 2>&1; then
      check_row ok "Embedding ucu" "calisiyor" "$embed_model"
    else
      check_row warn "Embedding ucu" "calisiyor" "yanit vermedi"
    fi
  else
    check_row warn "Embedding modeli" "opsiyonel" "yok"
    check_note "RAG icin: ollama pull nomic-embed-text"
  fi

  hr
  printf '  Sonuc: %s%d tamam%s, %s%d uyari%s, %s%d hata%s\n\n' \
    "$C_GREEN" "$CHECK_OK_COUNT" "$C_RESET" \
    "$C_YELLOW" "$CHECK_WARN_COUNT" "$C_RESET" \
    "$C_RED" "$CHECK_FAIL_COUNT" "$C_RESET"

  ((CHECK_FAIL_COUNT == 0)) || exit 1
}

# --- bench -----------------------------------------------------------------

print_metrics() {
  local label=$1 json=$2
  local load prompt_n prompt_d eval_n eval_d total tps ttft
  load="$(jq -r '.load_duration // 0' <<<"$json")"
  prompt_n="$(jq -r '.prompt_eval_count // 0' <<<"$json")"
  prompt_d="$(jq -r '.prompt_eval_duration // 0' <<<"$json")"
  eval_n="$(jq -r '.eval_count // 0' <<<"$json")"
  eval_d="$(jq -r '.eval_duration // 0' <<<"$json")"
  total="$(jq -r '.total_duration // 0' <<<"$json")"

  tps="$(awk -v c="$eval_n" -v d="$eval_d" 'BEGIN { printf "%.1f", (d > 0 ? c / (d/1000000000) : 0) }')"
  ttft="$(awk -v l="$load" -v p="$prompt_d" 'BEGIN { printf "%.2f", (l + p) / 1000000000 }')"

  printf '  %s %s %s %s %s %s\n' \
    "$(pad "$label" 12)" \
    "$(pad "$(ns_to_s "$load") s" 11)" \
    "$(pad "${ttft} s" 11)" \
    "$(pad "${tps} tok/s" 13)" \
    "$(pad "${prompt_n}→${eval_n}" 10)" \
    "$(ns_to_s "$total") s"
}

mode_bench() {
  [[ -n $MODEL ]] || MODEL="$(pick_model 0 || true)"
  [[ -n $MODEL ]] || die "Yerel model bulunamadi. Once indirin: ollama pull qwen2.5:3b"

  banner "Hiz olcumu" "model: ${MODEL} · ${TOKENS} token"

  local loaded="hayir"
  model_loaded "$MODEL" && loaded="evet"
  log_info "Model su an bellekte mi: ${loaded}"
  log_dim "Prompt: ${PROMPT}"
  if [[ $loaded == "hayir" ]]; then
    log_dim "Model yuklenecek; 1. cagri uzun surebilir (14B icin 30 sn'yi bulabilir)."
  fi
  printf '\n'

  # TOKEN sutunu: islenen istem tokeni → uretilen token
  printf '  %s%s %s %s %s %s %s%s\n' "$C_BOLD" \
    "$(pad "CAGRI" 12)" "$(pad "YUKLEME" 11)" "$(pad "ILK TOKEN" 11)" \
    "$(pad "HIZ" 13)" "$(pad "TOKEN" 10)" "TOPLAM" "$C_RESET"
  hr

  # NOT: burada with_spinner kullanilamaz; JSON yanitini okumamiz gerekiyor,
  # spinner ise komut ciktisini kendi gunluk dosyasina yonlendiriyor.
  local first second
  first="$(generate "$MODEL" "$PROMPT" "$TOKENS")" || die "Uretim cagrisi basarisiz."
  print_metrics "1. cagri" "$first"

  second="$(generate "$MODEL" "$PROMPT" "$TOKENS")" || die "Ikinci cagri basarisiz."
  print_metrics "2. cagri" "$second"
  hr

  local l1 l2
  l1="$(jq -r '.load_duration // 0' <<<"$first")"
  l2="$(jq -r '.load_duration // 0' <<<"$second")"
  printf '\n'
  if awk -v a="$l1" -v b="$l2" 'BEGIN { exit !(a > b * 2 && a > 1000000000) }'; then
    log_info "Ilk cagrida $(ns_to_s "$l1") s yukleme vardi; model artik bellekte."
    log_dim "Uygulamanizda ilk istegi onceden tetiklemek (warm-up) bu gecikmeyi gizler."
  else
    log_info "Model zaten bellekteydi; her iki cagri da sicak calisti."
  fi
  log_dim "Ollama modeli varsayilan olarak 5 dakika bellekte tutar (keep_alive)."
  printf '\n'
}

# --- embed -----------------------------------------------------------------

mode_embed() {
  [[ -n $MODEL ]] || MODEL="$(pick_model 1 || true)"
  [[ -n $MODEL ]] || die "Embedding modeli bulunamadi. Indirin: ollama pull nomic-embed-text"

  banner "Embedding olcumu" "model: ${MODEL}"

  local payload resp dim i start end ms total_ms=0 runs=3
  payload="$(jq -n --arg m "$MODEL" '{model: $m, input: "Kubernetes cluster kurulum notlari"}')"

  resp="$(api_post /api/embed "$payload")" || die "Embedding cagrisi basarisiz."
  dim="$(jq -r '.embeddings[0] | length' <<<"$resp" 2>/dev/null || echo 0)"
  ((dim > 0)) || die "Embedding donmedi. Model bir embedding modeli olmayabilir."

  log_ok "Vektor boyutu: ${dim}"

  printf '\n  %s%s %s%s\n' "$C_BOLD" "$(pad "CAGRI" 10)" "SURE" "$C_RESET"
  hr
  for ((i = 1; i <= runs; i++)); do
    start="$(date +%s%N)"
    api_post /api/embed "$payload" >/dev/null || true
    end="$(date +%s%N)"
    ms=$(((end - start) / 1000000))
    total_ms=$((total_ms + ms))
    printf '  %s %s ms\n' "$(pad "${i}." 10)" "$ms"
  done
  hr
  printf '  %sOrtalama%s   %s ms\n\n' "$C_BOLD" "$C_RESET" "$((total_ms / runs))"

  log_info "RAG icin: ${dim} boyutlu vektor, vektor veritabaninizda ayni boyut tanimlanmali."
  printf '\n'
}

case "$MODE" in
  smoke) mode_smoke ;;
  bench) mode_bench ;;
  embed) mode_embed ;;
  *) die "Gecersiz mod: ${MODE} (smoke, bench veya embed olmali)" ;;
esac
