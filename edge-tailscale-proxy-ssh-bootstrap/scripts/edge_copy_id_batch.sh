#!/usr/bin/env bash
set -euo pipefail

PASSWORD_FILE=""
KEY="${KEY:-$HOME/.ssh/id_ed25519.pub}"
PRIVATE_KEY="${PRIVATE_KEY:-$HOME/.ssh/id_ed25519}"
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-5}"
COPY_TIMEOUT="${COPY_TIMEOUT:-45}"

while (($#)); do
  case "$1" in
    --password-file) PASSWORD_FILE="${2:?missing --password-file value}"; shift 2 ;;
    -h|--help) echo "Usage: edge_copy_id_batch.sh --password-file targets.tsv"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ -r "$PASSWORD_FILE" ]] || { echo "Readable --password-file is required." >&2; exit 1; }
mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
[[ -r "$KEY" && -r "$PRIVATE_KEY" ]] || ssh-keygen -t ed25519 -N "" -f "$PRIVATE_KEY" >/dev/null
command -v sshpass >/dev/null || { sudo apt-get update; sudo apt-get install -y sshpass; }
command -v jq >/dev/null || { sudo apt-get update; sudo apt-get install -y jq; }

host_from_target() { printf '%s\n' "${1#*@}"; }
tailscale_host_online() {
  local target="$1" host short json
  host="$(host_from_target "$target")"
  [[ "$host" == *.ts.net ]] || return 0
  short="${host%%.*}"
  json="$(tailscale status --json 2>/dev/null)" || return 0
  printf '%s\n' "$json" | jq -e --arg host "$host." --arg short "$short" '.Peer[] | select((.DNSName == $host) or (.HostName == $short)) | .Online == true' >/dev/null
}
passwordless_ok() { ssh -o BatchMode=yes -o ConnectTimeout="$CONNECT_TIMEOUT" -o ConnectionAttempts=1 "$1" true >/dev/null 2>&1; }
ssh_port_open() { timeout "$CONNECT_TIMEOUT" bash -c ":</dev/tcp/$(host_from_target "$1")/22" >/dev/null 2>&1; }

ok=(); skipped=(); failed=()
while IFS=$'\t' read -r target password extra; do
  [[ -z "${target:-}" || "$target" == \#* ]] && continue
  [[ -z "${extra:-}" && -n "${password:-}" ]] || { echo "Bad line for $target" >&2; failed+=("$target"); continue; }
  echo "==> $target"
  tailscale_host_online "$target" || { echo "SKIP offline: $target"; skipped+=("$target"); continue; }
  passwordless_ok "$target" && { echo "Already passwordless: $target"; ok+=("$target"); continue; }
  ssh_port_open "$target" || { echo "SKIP no SSH port: $target"; skipped+=("$target"); continue; }
  if SSHPASS="$password" timeout "$COPY_TIMEOUT" sshpass -e ssh-copy-id -f -i "$KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout="$CONNECT_TIMEOUT" -o ConnectionAttempts=1 "$target" >/dev/null 2>&1 && passwordless_ok "$target"; then
    echo "OK: $target"; ok+=("$target")
  else
    echo "FAILED: $target" >&2; failed+=("$target")
  fi
done <"$PASSWORD_FILE"

printf '\nOK:\n'; ((${#ok[@]})) && printf '  %s\n' "${ok[@]}" || true
printf '\nSKIPPED:\n'; ((${#skipped[@]})) && printf '  %s\n' "${skipped[@]}" || true
printf '\nFAILED:\n'; ((${#failed[@]})) && printf '  %s\n' "${failed[@]}" || true
((${#failed[@]} == 0))
