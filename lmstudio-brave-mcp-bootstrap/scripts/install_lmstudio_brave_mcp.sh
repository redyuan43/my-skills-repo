#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

LMSTUDIO_DIR="${LMSTUDIO_DIR:-$HOME/.lmstudio}"
SERVER_NAME="brave-search"
API_KEY="${BRAVE_API_KEY:-}"
PROXY_URL="${ALL_PROXY:-}"
MODE="custom"
FORCE="0"

usage() {
  cat <<'EOF'
用法：
  bash scripts/install_lmstudio_brave_mcp.sh [选项]

选项：
  --api-key <key>         写入 Brave API key
  --proxy-url <url>       写入 MCP 专用代理，如 socks://127.0.0.1:10808/
  --mode <custom|official>
                         选择自定义增强版或官方 Brave MCP，默认 custom
  --lmstudio-dir <path>   指定 LM Studio 配置目录，默认 ~/.lmstudio
  --force                 覆盖已有 server 文件和凭证模板
  -h, --help              显示帮助

环境变量也可用：
  BRAVE_API_KEY
  ALL_PROXY
  LMSTUDIO_DIR
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --api-key)
      API_KEY="${2:-}"
      shift 2
      ;;
    --proxy-url)
      PROXY_URL="${2:-}"
      shift 2
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --lmstudio-dir)
      LMSTUDIO_DIR="${2:-}"
      shift 2
      ;;
    --force)
      FORCE="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "缺少依赖命令: $1" >&2
    exit 1
  fi
}

require_cmd "node"
require_cmd "curl"
require_cmd "python3"

if [[ "${MODE}" != "custom" && "${MODE}" != "official" ]]; then
  echo "--mode 只能是 custom 或 official" >&2
  exit 1
fi

BIN_DIR="${LMSTUDIO_DIR}/bin"
CREDENTIALS_DIR="${LMSTUDIO_DIR}/credentials"
SERVER_DIR="${LMSTUDIO_DIR}/mcp-servers/${SERVER_NAME}"
MCP_JSON="${LMSTUDIO_DIR}/mcp.json"
WRAPPER_FILE="${BIN_DIR}/brave-lmstudio-mcp.sh"
SERVER_FILE="${SERVER_DIR}/brave-lmstudio-mcp.mjs"
CREDENTIALS_FILE="${CREDENTIALS_DIR}/brave-search.env"
EXAMPLE_FILE="${CREDENTIALS_DIR}/brave-search.env.example"

mkdir -p "${BIN_DIR}" "${CREDENTIALS_DIR}" "${SERVER_DIR}"

copy_if_needed() {
  local src="$1"
  local dst="$2"
  if [[ -f "${dst}" && "${FORCE}" != "1" ]]; then
    return 0
  fi
  cp "${src}" "${dst}"
}

if [[ "${MODE}" == "custom" ]]; then
  copy_if_needed "${SKILL_ROOT}/assets/brave-lmstudio-mcp.sh" "${WRAPPER_FILE}"
  copy_if_needed "${SKILL_ROOT}/assets/brave-lmstudio-mcp.mjs" "${SERVER_FILE}"
else
  WRAPPER_FILE="${BIN_DIR}/brave-official-mcp.sh"
  copy_if_needed "${SKILL_ROOT}/assets/brave-official-mcp.sh" "${WRAPPER_FILE}"
fi
copy_if_needed "${SKILL_ROOT}/assets/brave-search.env.example" "${EXAMPLE_FILE}"

chmod 700 "${WRAPPER_FILE}"
chmod 600 "${EXAMPLE_FILE}"

if [[ ! -f "${CREDENTIALS_FILE}" || "${FORCE}" == "1" ]]; then
  cp "${SKILL_ROOT}/assets/brave-search.env.example" "${CREDENTIALS_FILE}"
fi

python3 - "${CREDENTIALS_FILE}" "${API_KEY}" "${PROXY_URL}" <<'PY'
import pathlib
import sys

credentials_path = pathlib.Path(sys.argv[1])
api_key = sys.argv[2]
proxy_url = sys.argv[3]

api_value = api_key or "YOUR_BRAVE_API_KEY"
lines = [f'export BRAVE_API_KEY="{api_value}"']
lines.append("")
lines.append("# 如果 Brave API 必须走代理，保留下面几行。")

if proxy_url:
    lines.append(f'export ALL_PROXY="{proxy_url}"')
    lines.append('export HTTPS_PROXY="$ALL_PROXY"')
    lines.append('export HTTP_PROXY="$ALL_PROXY"')
    lines.append('export NO_PROXY="localhost,127.0.0.0/8,::1"')
else:
    lines.append('# export ALL_PROXY="socks://127.0.0.1:10808/"')
    lines.append('# export HTTPS_PROXY="$ALL_PROXY"')
    lines.append('# export HTTP_PROXY="$ALL_PROXY"')
    lines.append('# export NO_PROXY="localhost,127.0.0.0/8,::1"')

credentials_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

chmod 600 "${CREDENTIALS_FILE}"

if [[ -f "${MCP_JSON}" ]]; then
  cp "${MCP_JSON}" "${MCP_JSON}.bak-$(date +%Y%m%d-%H%M%S)"
fi

python3 - "${MCP_JSON}" "${WRAPPER_FILE}" <<'PY'
import json
import pathlib
import sys

mcp_json_path = pathlib.Path(sys.argv[1])
command_path = sys.argv[2]

if mcp_json_path.exists():
    try:
        data = json.loads(mcp_json_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        data = {}
else:
    data = {}

if not isinstance(data, dict):
    data = {}

mcp_servers = data.get("mcpServers")
if not isinstance(mcp_servers, dict):
    mcp_servers = {}

mcp_servers["brave-search"] = {
    "command": command_path,
    "args": [],
}

data["mcpServers"] = mcp_servers
mcp_json_path.write_text(
    json.dumps(data, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY

echo
echo "LM Studio Brave MCP 已写入："
echo "  - ${MCP_JSON}"
echo "  - ${WRAPPER_FILE}"
if [[ "${MODE}" == "custom" ]]; then
  echo "  - ${SERVER_FILE}"
fi
echo "  - ${CREDENTIALS_FILE}"
echo "  - mode=${MODE}"
echo
if [[ "${API_KEY}" == "" ]]; then
  echo "注意：当前凭证文件写入的是占位符，请把真实 Brave API key 填进 ${CREDENTIALS_FILE}"
fi
echo "下一步：重启 LM Studio，然后新开聊天测试 brave_web_search。"
