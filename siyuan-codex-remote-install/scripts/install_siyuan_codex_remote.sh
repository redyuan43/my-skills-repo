#!/usr/bin/env bash
set -euo pipefail

repo="redyuan43/codex"
host=""
hosts=()
all_hosts=0
version="latest"
nano_password="${SIYUAN_NANO_PASSWORD:-}"
fleet_hosts=(AMD ai agx nano nano@nano2)

usage() {
  cat <<'EOF'
Usage:
  install_siyuan_codex_remote.sh --host <ssh-host> [--repo owner/name] [--version <version>]
  install_siyuan_codex_remote.sh --all [--repo owner/name] [--version <version>] [--nano-password <password>]
  install_siyuan_codex_remote.sh --hosts "AMD ai agx nano nano@nano2" [--version <version>]

Installs the Siyuan-branded Codex CLI from a GitHub release into the remote
user's home directory:
  ~/.local/share/siyuan-codex/<version>
  ~/.local/bin/siyuan
  ~/.local/bin/codex

The script downloads the release asset locally first, then transfers it with scp.

Fleet mode defaults to these SSH targets:
  AMD ai agx nano nano@nano2

For password-only Nano devices, pass --nano-password or set SIYUAN_NANO_PASSWORD.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      host="${2:-}"
      shift 2
      ;;
    --hosts)
      if [[ $# -lt 2 ]]; then
        echo "--hosts requires a space-separated host list" >&2
        exit 2
      fi
      read -r -a hosts <<<"${2:-}"
      shift 2
      ;;
    --all)
      all_hosts=1
      shift
      ;;
    --repo)
      repo="${2:-}"
      shift 2
      ;;
    --version)
      version="${2:-}"
      shift 2
      ;;
    --nano-password)
      nano_password="${2:-}"
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

if [[ "$all_hosts" == "1" ]]; then
  hosts=("${fleet_hosts[@]}")
elif [[ ${#hosts[@]} -eq 0 && -n "$host" ]]; then
  hosts=("$host")
fi

if [[ ${#hosts[@]} -eq 0 ]]; then
  echo "--host, --hosts, or --all is required" >&2
  usage >&2
  exit 2
fi

if printf '%s\n' "${hosts[@]}" | grep -Eq '^(nano|nano2|nano@nano2)$'; then
  if [[ -n "$nano_password" ]] && ! command -v sshpass >/dev/null 2>&1; then
    echo "sshpass is required for password-only Nano hosts." >&2
    exit 2
  fi
fi

release_json="$(mktemp)"
asset_path=""
cleanup() {
  rm -f "$release_json"
  if [[ -n "$asset_path" ]]; then
    rm -f "$asset_path"
  fi
}
trap cleanup EXIT

if [[ "$version" == "latest" ]]; then
  api_url="https://api.github.com/repos/${repo}/releases/latest"
else
  api_url="https://api.github.com/repos/${repo}/releases/tags/siyuan-v${version}"
fi

curl -fsSL "$api_url" -o "$release_json"

read -r tag_name asset_name asset_url resolved_version < <(
  python3 - "$release_json" "$version" <<'PY'
import json
import re
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text())
requested = sys.argv[2]
assets = data.get("assets") or []
asset = next((a for a in assets if re.match(r"^siyuan-codex-npm-.+\.tgz$", a.get("name", ""))), None)
if asset is None:
    names = ", ".join(a.get("name", "") for a in assets)
    raise SystemExit(f"No siyuan-codex npm tgz asset found. Assets: {names}")
name = asset["name"]
match = re.match(r"^siyuan-codex-npm-(.+)\.tgz$", name)
version = requested if requested != "latest" else (match.group(1) if match else data["tag_name"].removeprefix("siyuan-v"))
print(data["tag_name"], name, asset["browser_download_url"], version)
PY
)

asset_path="/tmp/${asset_name}"
echo "Release: ${tag_name}"
echo "Asset: ${asset_name}"
echo "Hosts: ${hosts[*]}"

curl -fL --retry 3 --connect-timeout 20 -o "$asset_path" "$asset_url"

host_needs_password() {
  case "$1" in
    nano|nano2|nano@nano2)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

normalize_host() {
  case "$1" in
    nano2)
      printf 'nano@nano2\n'
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

ssh_run() {
  local target="$1"
  shift
  if host_needs_password "$target"; then
    if [[ -z "$nano_password" ]]; then
      echo "Host $target requires --nano-password or SIYUAN_NANO_PASSWORD" >&2
      return 2
    fi
    SSHPASS="$nano_password" sshpass -e ssh \
      -o PreferredAuthentications=password \
      -o PubkeyAuthentication=no \
      -o StrictHostKeyChecking=accept-new \
      -o ConnectTimeout=10 \
      "$target" "$@"
  else
    ssh -o BatchMode=yes -o ConnectTimeout=10 "$target" "$@"
  fi
}

scp_to() {
  local source="$1"
  local target="$2"
  local dest="$3"
  if host_needs_password "$target"; then
    if [[ -z "$nano_password" ]]; then
      echo "Host $target requires --nano-password or SIYUAN_NANO_PASSWORD" >&2
      return 2
    fi
    SSHPASS="$nano_password" sshpass -e scp \
      -o PreferredAuthentications=password \
      -o PubkeyAuthentication=no \
      -o StrictHostKeyChecking=accept-new \
      "$source" "${target}:${dest}"
  else
    scp "$source" "${target}:${dest}"
  fi
}

install_one_host() {
  local target="$1"
  local remote_asset=".cache/${asset_name}"

  echo
  echo "===== ${target} ====="
  ssh_run "$target" 'mkdir -p "$HOME/.cache"'
  scp_to "$asset_path" "$target" "$remote_asset"

  ssh_run "$target" "bash -s" <<REMOTE_SCRIPT
set -euo pipefail
VERSION="${resolved_version}"
ASSET="\$HOME/${remote_asset}"
APP_ROOT="\$HOME/.local/share/siyuan-codex/\${VERSION}"
BIN_DIR="\$HOME/.local/bin"
TMP_DIR="\$(mktemp -d)"
trap 'rm -rf "\$TMP_DIR"' EXIT

case "\$(uname -m)" in
  aarch64|arm64)
    TARGET_TRIPLE="aarch64-unknown-linux-musl"
    ;;
  x86_64|amd64)
    TARGET_TRIPLE="x86_64-unknown-linux-musl"
    ;;
  *)
    echo "Unsupported remote architecture: \$(uname -m)" >&2
    exit 1
    ;;
esac

test -s "\$ASSET"
mkdir -p "\$APP_ROOT" "\$BIN_DIR"
tar -xzf "\$ASSET" -C "\$TMP_DIR"
rm -rf "\$APP_ROOT/package"
mv "\$TMP_DIR/package" "\$APP_ROOT/package"
chmod +x "\$APP_ROOT/package/vendor/\$TARGET_TRIPLE/codex/codex"
chmod +x "\$APP_ROOT/package/vendor/\$TARGET_TRIPLE/path/codex-linux-sandbox"

WRAPPER="\$APP_ROOT/siyuan-codex"
cat > "\$WRAPPER" <<'WRAPPER_EOF'
#!/usr/bin/env bash
set -euo pipefail
SELF="\$(readlink -f "\${BASH_SOURCE[0]}")"
APP_ROOT="\$(cd "\$(dirname "\$SELF")" && pwd)"
PACKAGE_ROOT="\$APP_ROOT/package"
export CODEX_MANAGED_BY_NPM=1
export CODEX_MANAGED_PACKAGE_ROOT="\$PACKAGE_ROOT"
exec "\$PACKAGE_ROOT/vendor/__TARGET_TRIPLE__/codex/codex" "\$@"
WRAPPER_EOF
python3 - "\$WRAPPER" "\$TARGET_TRIPLE" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
target = sys.argv[2]
path.write_text(path.read_text().replace("__TARGET_TRIPLE__", target))
PY
chmod +x "\$WRAPPER"
ln -sfn "\$WRAPPER" "\$BIN_DIR/siyuan"
ln -sfn "\$WRAPPER" "\$BIN_DIR/codex"

touch "\$HOME/.bashrc"
if [[ -f "\$HOME/.bashrc" ]]; then
  backup="\$HOME/.bashrc.siyuan-codex-backup-\$(date +%Y%m%d%H%M%S)"
  cp "\$HOME/.bashrc" "\$backup"
  python3 - "\$HOME/.bashrc" "\$BIN_DIR" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
bin_dir = sys.argv[2]
text = path.read_text()
replacements = {
    "alias codex=": f"alias codex='{bin_dir}/codex'",
    "alias siyuan=": f"alias siyuan='{bin_dir}/siyuan'",
}

lines = []
seen = {key: False for key in replacements}
for line in text.splitlines():
    stripped = line.strip()
    for prefix, replacement in replacements.items():
        if stripped.startswith(prefix):
            lines.append(replacement)
            seen[prefix] = True
            break
    else:
        lines.append(line)

for prefix, replacement in replacements.items():
    if not seen[prefix]:
        lines.append(replacement)

path.write_text("\n".join(lines) + "\n")
PY
fi

printf 'siyuan_path='
readlink -f "\$BIN_DIR/siyuan"
printf 'codex_path='
readlink -f "\$BIN_DIR/codex"
printf 'version='
"\$BIN_DIR/siyuan" --version
REMOTE_SCRIPT

  ssh_run "$target" "bash -ic 'command -v siyuan; siyuan --version; command -v codex; codex --version'"
}

failures=0
for target in "${hosts[@]}"; do
  target="$(normalize_host "$target")"
  if install_one_host "$target"; then
    echo "OK: ${target}"
  else
    status=$?
    echo "FAILED: ${target} status=${status}" >&2
    failures=$((failures + 1))
  fi
done

if ((failures)); then
  echo "Complete with failures=${failures}" >&2
  exit 1
fi

echo "Complete: all hosts upgraded to ${resolved_version}"
