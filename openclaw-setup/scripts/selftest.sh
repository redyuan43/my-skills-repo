#!/usr/bin/env bash
set -euo pipefail

SAFE=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<'EOF'
用法:
  selftest.sh --safe
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --safe) SAFE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ "${SAFE}" -ne 1 ]]; then
  echo "此 selftest 只支持 --safe，避免安装、联网或写入 OpenClaw live 配置。" >&2
  exit 2
fi

for path in \
  "${SKILL_DIR}/SKILL.md" \
  "${SKILL_DIR}/references/install_methods.md" \
  "${SKILL_DIR}/references/provider_config.md" \
  "${SKILL_DIR}/references/gateway_ops.md" \
  "${SKILL_DIR}/references/troubleshooting.md"; do
  [[ -s "${path}" ]] || { echo "缺少文件: ${path}" >&2; exit 1; }
done

rg -q "references/install_methods.md" "${SKILL_DIR}/SKILL.md"
rg -q "不要把真实 API key" "${SKILL_DIR}/SKILL.md"
rg -q "openai-completions" "${SKILL_DIR}/references/provider_config.md"
rg -q "openclaw gateway status" "${SKILL_DIR}/references/gateway_ops.md"

echo "selftest passed: openclaw-setup safe checks"
