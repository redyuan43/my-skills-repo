#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="/home/ivan/github/PyWxDump"
URL=""
OUTPUT_DIR=""
DOC_TYPE=""
CHAT_NAME=""
CHAT_ID=""

usage() {
  cat <<'EOF'
用法:
  wechat_link_to_doc.sh --url URL --output-dir DIR [--doc-type wechat_article|generic_web] [--chat-name NAME] [--chat-id ID]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url) URL="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --doc-type) DOC_TYPE="$2"; shift 2 ;;
    --chat-name) CHAT_NAME="$2"; shift 2 ;;
    --chat-id) CHAT_ID="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "${URL}" || -z "${OUTPUT_DIR}" ]]; then
  usage
  exit 2
fi

if [[ ! -d "${REPO_ROOT}" ]]; then
  echo "未找到 PyWxDump 仓库: ${REPO_ROOT}" >&2
  exit 1
fi

if [[ -z "${DOC_TYPE}" ]]; then
  if [[ "${URL}" == https://mp.weixin.qq.com/* ]]; then
    DOC_TYPE="wechat_article"
  else
    DOC_TYPE="generic_web"
  fi
fi

mkdir -p "${OUTPUT_DIR}"
cd "${REPO_ROOT}"

python3 - "${URL}" "${OUTPUT_DIR}" "${DOC_TYPE}" "${CHAT_NAME}" "${CHAT_ID}" <<'PY' | python3 "tools/link_doc_hook.py"
import json
import sys

url, output_dir, doc_type, chat_name, chat_id = sys.argv[1:]
payload = {
    "doc_type": doc_type,
    "url_list": [url],
    "output_dir": output_dir,
    "title": url,
    "summary": url,
    "chat_name": chat_name,
    "chat_id": chat_id,
}
print(json.dumps(payload, ensure_ascii=False))
PY
