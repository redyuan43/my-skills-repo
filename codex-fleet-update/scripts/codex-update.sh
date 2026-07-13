#!/usr/bin/env bash
set -u -o pipefail

HOSTS_DEFAULT=(nano nano2 nano3 nx1 nx2 nx3 nx4 agx AMD ivan edge spark)
REPO_DEFAULT="redyuan43/codex"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/codex-fleet-update"
LOG_FILE="$STATE_DIR/update.log"
LOCK_FILE="$STATE_DIR/lock"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=12)
RSYNC_RSH="ssh -o BatchMode=yes -o ConnectTimeout=12 -o ServerAliveInterval=15 -o ServerAliveCountMax=4"
UPLOAD_ATTEMPTS=5

usage() {
  cat <<'USAGE'
Usage: codex-update [--check] [--hosts "nano nx1 ..."] [--target VERSION]
                    [--repo OWNER/REPO]

Aligns an SSH fleet with the latest Siyuan Codex GitHub release. The command
downloads each required architecture once, verifies the release checksum, and
atomically switches the remote codex/siyuan launchers.

Options:
  --check          Report versions only; do not download or install.
  --hosts LIST     Space-separated SSH aliases to update.
  --target VER     Install a specific Siyuan version or release tag.
  --repo REPO      GitHub repository containing Siyuan releases.
  -h, --help       Show this help.
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

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command is missing: $1" >&2
    exit 1
  fi
}

release_tag_for_target() {
  local requested="$1"
  if [[ "$requested" == siyuan-v* ]]; then
    printf '%s\n' "$requested"
  else
    printf 'siyuan-v%s\n' "$requested"
  fi
}

asset_arch_for_machine() {
  case "$1" in
    aarch64|arm64)
      printf 'aarch64-unknown-linux-musl\n'
      ;;
    x86_64|amd64)
      printf 'x86_64-unknown-linux-musl\n'
      ;;
    *)
      return 1
      ;;
  esac
}

upload_asset() {
  local asset_path="$1"
  local host="$2"
  local remote_asset="$3"
  local attempt

  for ((attempt = 1; attempt <= UPLOAD_ATTEMPTS; attempt++)); do
    if rsync --partial --append-verify --timeout=120 -e "$RSYNC_RSH" \
        "$asset_path" "$host:$remote_asset"; then
      return
    fi
    log "upload_retry host=$host attempt=$attempt max_attempts=$UPLOAD_ATTEMPTS"
    sleep "$((attempt * 5))"
  done
  return 1
}

check_only=0
target=""
repo="$REPO_DEFAULT"
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
    --repo)
      if (($# < 2)); then
        echo "Missing value for --repo" >&2
        exit 2
      fi
      repo="$2"
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

require_command gh
require_command ssh
require_command rsync
require_command sha256sum
require_command flock

mkdir -p "$STATE_DIR"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "Another codex-update run is already active." >&2
  exit 1
fi

if [[ -z "$target" ]]; then
  if ! tag="$(
    gh api "repos/$repo/releases?per_page=100" \
      --jq 'map(select(.draft == false and (.tag_name | startswith("siyuan-v")))) | first | .tag_name' \
      2>/dev/null
  )" || [[ -z "$tag" ]]; then
    echo "Could not query the latest Siyuan GitHub release for $repo" >&2
    exit 1
  fi
else
  tag="$(release_tag_for_target "$target")"
fi

if [[ "$tag" != siyuan-v* ]]; then
  echo "Latest release is not a Siyuan release: $tag" >&2
  exit 1
fi
version="${tag#siyuan-v}"

stage_dir=""
checksum_file=""
# shellcheck disable=SC2317
cleanup() {
  if [[ -n "$stage_dir" ]]; then
    rm -rf "$stage_dir"
  fi
}
trap cleanup EXIT

prepare_asset() {
  local asset_arch="$1"
  local asset_name="siyuan-codex-$version-$asset_arch.tar.gz"
  local asset_path="$stage_dir/$asset_name"
  local expected

  if [[ -f "$asset_path" ]]; then
    printf '%s\n' "$asset_path"
    return
  fi

  log "download asset=$asset_name tag=$tag" >&2
  if ! gh release download "$tag" --repo "$repo" --dir "$stage_dir" \
      --pattern "$asset_name" --clobber; then
    return 1
  fi

  expected="$(awk -v name="$asset_name" '$2 == name { print $1 }' "$checksum_file")"
  if [[ -z "$expected" ]]; then
    echo "Checksum is missing for release asset: $asset_name" >&2
    return 1
  fi
  if ! printf '%s  %s\n' "$expected" "$asset_path" | sha256sum --check --status; then
    echo "Checksum verification failed for release asset: $asset_name" >&2
    return 1
  fi

  log "verified asset=$asset_name sha256=$expected" >&2
  printf '%s\n' "$asset_path"
}

# These scripts intentionally expand on the remote host.
# shellcheck disable=SC2016
remote_check_script='
set -u
target="$1"
printf "hostname=%s user=%s\n" "$(hostname)" "$USER"
machine="$(uname -m)"
printf "machine=%s\n" "$machine"
codex_path="$(type -P codex 2>/dev/null || command -v codex 2>/dev/null || true)"
codex_version="$(codex --version 2>/dev/null | awk "{print \$2}" || true)"
printf "codex_path=%s\n" "${codex_path:-missing}"
printf "codex_version=%s\n" "${codex_version:-missing}"
printf "target=%s\n" "$target"
[[ "$codex_version" == "$target" ]]
'

# shellcheck disable=SC2016
remote_install_script='
set -euo pipefail
version="$1"
archive="$2"
base="$HOME/.local/share/siyuan-codex"
dest="$base/$version"
tmp="$base/.${version}.tmp.$$"

mkdir -p "$base" "$HOME/.local/bin"
rm -rf "$tmp"
mkdir -p "$tmp"
tar -xzf "$archive" -C "$tmp"

actual="$("$tmp/codex" --version | awk "{print \$2}")"
if [[ "$actual" != "$version" ]]; then
  echo "archive version mismatch: expected=$version actual=$actual" >&2
  exit 21
fi

printf "#!/usr/bin/env bash\nset -euo pipefail\nexec \"%s/codex\" \"\$@\"\n" "$dest" \
  >"$tmp/siyuan-codex"
chmod 755 "$tmp/codex" "$tmp/codex-linux-sandbox" "$tmp/siyuan-codex"
rm -rf "$dest"
mv "$tmp" "$dest"
ln -sfn "$dest/siyuan-codex" "$HOME/.local/bin/codex"
ln -sfn "$dest/siyuan-codex" "$HOME/.local/bin/siyuan"
rm -f "$archive"
hash -r

after_version="$("$HOME/.local/bin/codex" --version | awk "{print \$2}")"
printf "codex_path_after=%s\n" "$(readlink -f "$HOME/.local/bin/codex")"
printf "codex_version_after=%s\n" "$after_version"
[[ "$after_version" == "$version" ]]
'

log "start check_only=$check_only repo=$repo tag=$tag target=$version hosts=$(quote_words "${hosts[@]}")"

if ((check_only == 0)); then
  stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/codex-fleet-update.XXXXXX")"
  checksum_name="siyuan-codex-$version-checksums.txt"
  if ! gh release download "$tag" --repo "$repo" --dir "$stage_dir" \
      --pattern "$checksum_name" --clobber; then
    echo "Could not download release checksums for $tag" >&2
    exit 1
  fi
  checksum_file="$stage_dir/$checksum_name"
fi

failures=0
for host in "${hosts[@]}"; do
  log "===== $host ====="

  check_output="$(
    # shellcheck disable=SC2029
    ssh "${SSH_OPTS[@]}" "$host" \
      "bash -ic $(printf '%q' "$remote_check_script") -- $(printf '%q' "$version")" \
      2>&1
  )"
  check_status=$?
  printf '%s\n' "$check_output" \
    | sed '/cannot set terminal process group/d;/no job control/d;/Connection to .* closed/d;/^exit$/d' \
    | tee -a "$LOG_FILE"

  if ((check_status == 0)); then
    log "ok host=$host already_latest=yes"
    continue
  fi
  if ((check_only == 1)); then
    log "outdated_or_unreachable host=$host status=$check_status"
    failures=$((failures + 1))
    continue
  fi

  machine="$(
    printf '%s\n' "$check_output" \
      | sed -n 's/^machine=//p' \
      | tail -1
  )"
  if ! asset_arch="$(asset_arch_for_machine "$machine")"; then
    log "failed host=$host unsupported_machine=${machine:-missing}"
    failures=$((failures + 1))
    continue
  fi
  if ! asset_path="$(prepare_asset "$asset_arch")"; then
    log "failed host=$host asset_prepare_failed=$asset_arch"
    failures=$((failures + 1))
    continue
  fi

  remote_asset="/tmp/$(basename "$asset_path")"
  if ! upload_asset "$asset_path" "$host" "$remote_asset"; then
    log "failed host=$host upload_failed=yes"
    failures=$((failures + 1))
    continue
  fi
  if ssh "${SSH_OPTS[@]}" "$host" bash -s -- "$version" "$remote_asset" \
      <<<"$remote_install_script" 2>&1 | tee -a "$LOG_FILE"; then
    log "ok host=$host updated=yes"
  else
    status=$?
    log "failed host=$host install_status=$status"
    failures=$((failures + 1))
  fi
done

log "complete failures=$failures"
exit "$failures"
