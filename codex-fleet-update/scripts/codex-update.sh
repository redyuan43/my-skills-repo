#!/usr/bin/env bash
set -u -o pipefail

HOSTS_DEFAULT=(nano nx1 nx2 agx AMD ivan edge spark)
PACKAGE="@openai/codex"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/codex-fleet-update"
LOG_FILE="$STATE_DIR/update.log"
LOCK_FILE="$STATE_DIR/lock"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=12)

usage() {
  cat <<'USAGE'
Usage: codex-update [--check] [--hosts "nano nx1 ..."] [--target VERSION]

Updates @openai/codex on the configured SSH fleet using each host's own
interactive bash/npm environment. No timer, no background polling.

Options:
  --check          Report versions only; do not install.
  --hosts LIST    Space-separated SSH aliases to update.
  --target VER    Install a specific version instead of npm latest.
  -h, --help      Show this help.
USAGE
}

log() {
  mkdir -p "$STATE_DIR"
  printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE"
}

quote_words() {
  local word
  for word in "$@"; do
    printf '%q ' "$word"
  done
}

check_only=0
target=""
hosts=("${HOSTS_DEFAULT[@]}")

while (($#)); do
  case "$1" in
    --check)
      check_only=1
      shift
      ;;
    --hosts)
      if (($# < 2)); then
        echo "Missing value for --hosts" >&2
        exit 2
      fi
      read -r -a hosts <<<"$2"
      shift 2
      ;;
    --target)
      if (($# < 2)); then
        echo "Missing value for --target" >&2
        exit 2
      fi
      target="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "$STATE_DIR"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "Another codex-update run is already active." >&2
  exit 1
fi

if [[ -z "$target" ]]; then
  if ! target="$(npm view "$PACKAGE" version --fetch-timeout=20000 2>/dev/null)"; then
    echo "Could not query npm latest version for $PACKAGE" >&2
    exit 1
  fi
fi

remote_script='
set -u
target="$1"
check_only="$2"
printf "host=%s user=%s\n" "$(hostname)" "$USER"
if ! command -v npm >/dev/null 2>&1; then
  echo "npm=missing"
  exit 20
fi
before_path="$(command -v codex 2>/dev/null || true)"
before_version="$(codex --version 2>/dev/null | awk "{print \$2}" || true)"
printf "codex_path_before=%s\n" "${before_path:-missing}"
printf "codex_version_before=%s\n" "${before_version:-missing}"
printf "npm_path=%s\n" "$(command -v npm)"
printf "target=%s\n" "$target"
if [[ "$check_only" != "1" && "$before_version" != "$target" ]]; then
  npm install -g "@openai/codex@$target"
  hash -r
elif [[ "$check_only" != "1" ]]; then
  echo "already_latest=yes"
fi
after_path="$(command -v codex 2>/dev/null || true)"
after_version="$(codex --version 2>/dev/null | awk "{print \$2}" || true)"
printf "codex_path_after=%s\n" "${after_path:-missing}"
printf "codex_version_after=%s\n" "${after_version:-missing}"
if [[ "$after_version" != "$target" ]]; then
  exit 21
fi
'

log "start check_only=$check_only target=$target hosts=$(quote_words "${hosts[@]}")"

failures=0
for host in "${hosts[@]}"; do
  log "===== $host ====="
  if ssh "${SSH_OPTS[@]}" "$host" "bash -ic $(printf '%q' "$remote_script") -- $(printf '%q' "$target") $(printf '%q' "$check_only")" \
      2>&1 | sed '/cannot set terminal process group/d;/no job control/d;/Connection to .* closed/d' | tee -a "$LOG_FILE"; then
    log "ok host=$host"
  else
    status=$?
    log "failed host=$host status=$status"
    failures=$((failures + 1))
  fi
done

if ((failures)); then
  log "complete failures=$failures"
  exit 1
fi

log "complete failures=0"
