#!/usr/bin/env bash
set -euo pipefail

repo="redyuan43/codex"
host=""
version="latest"

usage() {
  cat <<'EOF'
Usage:
  install_siyuan_codex_remote.sh --host <ssh-host> [--repo owner/name] [--version <version>]

Installs the Siyuan-branded Codex CLI from a GitHub release into the remote
user's home directory:
  ~/.local/share/siyuan-codex/<version>
  ~/.local/bin/siyuan
  ~/.local/bin/codex

The script downloads the release asset locally first, then transfers it with scp.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      host="${2:-}"
      shift 2
      ;;
    --repo)
      repo="${2:-}"
      shift 2
      ;;
    --version)
      version="${2:-}"
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

if [[ -z "$host" ]]; then
  echo "--host is required" >&2
  usage >&2
  exit 2
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
echo "Host: ${host}"

curl -fL --retry 3 --connect-timeout 20 -o "$asset_path" "$asset_url"
remote_asset=".cache/${asset_name}"
scp "$asset_path" "${host}:${remote_asset}"

ssh "$host" "bash -s" <<REMOTE_SCRIPT
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
cat > "\$WRAPPER" <<WRAPPER_EOF
#!/usr/bin/env bash
set -euo pipefail
SELF="\$(readlink -f "\${BASH_SOURCE[0]}")"
APP_ROOT="\$(cd "\$(dirname "\$SELF")" && pwd)"
PACKAGE_ROOT="\$APP_ROOT/package"
export CODEX_MANAGED_BY_NPM=1
export CODEX_MANAGED_PACKAGE_ROOT="\$PACKAGE_ROOT"
exec "\$PACKAGE_ROOT/vendor/\${TARGET_TRIPLE}/codex/codex" "\$@"
WRAPPER_EOF
chmod +x "\$WRAPPER"
ln -sfn "\$WRAPPER" "\$BIN_DIR/siyuan"
ln -sfn "\$WRAPPER" "\$BIN_DIR/codex"

printf 'siyuan_path='
readlink -f "\$BIN_DIR/siyuan"
printf 'codex_path='
readlink -f "\$BIN_DIR/codex"
printf 'version='
"\$BIN_DIR/siyuan" --version
REMOTE_SCRIPT

ssh "$host" "bash -ic 'command -v siyuan; siyuan --version; command -v codex; codex --version'"
