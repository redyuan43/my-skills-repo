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
  echo "此 selftest 只支持 --safe，避免安装、修复或写入 PyWxDump 配置。" >&2
  exit 2
fi

[[ -s "${SKILL_DIR}/SKILL.md" ]] || { echo "缺少 SKILL.md" >&2; exit 1; }
[[ -s "${SKILL_DIR}/scripts/bootstrap_with_profiles.sh" ]] || { echo "缺少 bootstrap_with_profiles.sh" >&2; exit 1; }

rg -q "tools/bootstrap_linux_wechat_stack.py" "${SKILL_DIR}/SKILL.md"
rg -q "install.*可能调用.*sudo apt-get" "${SKILL_DIR}/SKILL.md"
bash -n "${SKILL_DIR}/scripts/bootstrap_with_profiles.sh"

echo "selftest passed: pywxdump-linux-bootstrap safe checks"
