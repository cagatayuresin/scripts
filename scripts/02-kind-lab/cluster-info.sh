#!/usr/bin/env bash
#
# cluster-info.sh - kind cluster'larinin durumunu gosterir.
#
#   make kind-status -> --mode status : tek cluster'in node/pod/depo durumu
#   make kind-list   -> --mode list   : makinedeki tum kind cluster'lari

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh disable=SC1091
source "${REPO_ROOT}/lib/common.sh"
enable_error_trap

MODE="status"
NAME="lab"
REG_NAME="kind-registry"
REG_PORT=5001

usage() {
  cat <<'EOF'
Kullanim: cluster-info.sh [SECENEKLER]

Secenekler:
  --mode <status|list>   Gosterilecek bilgi (varsayilan: status)
  --name <ad>            status modunda hedef cluster (varsayilan: lab)
  --registry-port <p>    Imaj deposu portu (varsayilan: 5001)
  --no-color             Renkli ciktiyi kapatir
  -h, --help             Bu yardimi gosterir
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --name)
      NAME="$2"
      shift 2
      ;;
    --registry-port)
      REG_PORT="$2"
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

require_cmd kind "Kurulum: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"

CONTEXT="kind-${NAME}"

registry_state() {
  local running
  running="$(docker inspect -f '{{.State.Running}}' "$REG_NAME" 2>/dev/null || true)"
  case "$running" in
    true) printf 'calisiyor (localhost:%s)' "$REG_PORT" ;;
    false) printf 'durdurulmus' ;;
    *) printf 'kurulu degil' ;;
  esac
}

case "$MODE" in
  list)
    banner "kind cluster'lari" "makinedeki tum cluster'lar"
    clusters="$(kind get clusters 2>/dev/null || true)"
    if [[ -z $clusters ]]; then
      log_info "Hic kind cluster'i yok."
      log_dim "Kurmak icin: make kind-up"
      printf '\n'
      exit 0
    fi

    current="$(kubectl config current-context 2>/dev/null || true)"
    printf '  %s%s %s %s%s\n' "$C_BOLD" \
      "$(pad "CLUSTER" 20)" "$(pad "NODE" 6)" "CONTEXT" "$C_RESET"
    hr
    while read -r c; do
      [[ -z $c ]] && continue
      count="$(kind get nodes --name "$c" 2>/dev/null | grep -c . || true)"
      marker=""
      [[ "kind-${c}" == "$current" ]] && marker=" ${C_GREEN}← aktif${C_RESET}"
      printf '  %s %s kind-%s%s\n' "$(pad "$c" 20)" "$(pad "${count:-0}" 6)" "$c" "$marker"
    done <<<"$clusters"
    hr
    printf '\n  Imaj deposu: %s\n\n' "$(registry_state)"
    ;;

  status)
    if ! kind get clusters 2>/dev/null | grep -qx -- "$NAME"; then
      banner "Durum" "cluster: ${NAME}"
      log_warn "'${NAME}' adinda bir kind cluster'i yok."
      log_dim "Kurmak icin    : make kind-up KIND_NAME=${NAME}"
      log_dim "Listelemek icin: make kind-list"
      printf '\n'
      exit 0
    fi

    banner "Durum" "cluster: ${NAME} · context: ${CONTEXT}"

    printf '  %sNode'\''lar%s\n' "$C_BOLD" "$C_RESET"
    kubectl --context "$CONTEXT" get nodes -o wide 2>/dev/null | sed 's/^/    /' ||
      log_err "Cluster'a erisilemedi."

    printf '\n  %sCalismayan pod'\''lar%s\n' "$C_BOLD" "$C_RESET"
    not_running="$(kubectl --context "$CONTEXT" get pods -A --no-headers 2>/dev/null |
      awk '$4 != "Running" && $4 != "Completed"' || true)"
    if [[ -n $not_running ]]; then
      printf '%s\n' "$not_running" | sed 's/^/    /'
    else
      log_ok "Tum pod'lar calisiyor"
    fi

    printf '\n  %sOzet%s\n' "$C_BOLD" "$C_RESET"
    pod_count="$(kubectl --context "$CONTEXT" get pods -A --no-headers 2>/dev/null | grep -c . || true)"
    ns_count="$(kubectl --context "$CONTEXT" get ns --no-headers 2>/dev/null | grep -c . || true)"
    printf '    Pod: %s · Namespace: %s · Imaj deposu: %s\n' \
      "${pod_count:-0}" "${ns_count:-0}" "$(registry_state)"

    current="$(kubectl config current-context 2>/dev/null || true)"
    if [[ $current != "$CONTEXT" ]]; then
      printf '\n'
      log_warn "Aktif context farkli: ${current:-yok}"
      log_cmd "kubectl config use-context ${CONTEXT}"
    fi
    printf '\n'
    ;;

  *)
    die "Gecersiz mod: ${MODE} (status veya list olmali)"
    ;;
esac
