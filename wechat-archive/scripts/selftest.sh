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
  echo "此 selftest 只支持 --safe，避免索引、部署或写入 systemd 配置。" >&2
  exit 2
fi

for path in \
  "${SKILL_DIR}/SKILL.md" \
  "${SKILL_DIR}/references/index_ops.md" \
  "${SKILL_DIR}/references/systemd_ops.md" \
  "${SKILL_DIR}/references/deploy_ops.md" \
  "${SKILL_DIR}/scripts/archive_locator.py" \
  "${SKILL_DIR}/scripts/run_wechat_archive_agent.sh"; do
  [[ -s "${path}" ]] || { echo "缺少文件: ${path}" >&2; exit 1; }
done

rg -q "默认只做只读" "${SKILL_DIR}/SKILL.md"
rg -q "index" "${SKILL_DIR}/references/index_ops.md"
rg -q "systemctl --user" "${SKILL_DIR}/references/systemd_ops.md"
rg -q -- "--http-url" "${SKILL_DIR}/references/deploy_ops.md"
bash -n "${SKILL_DIR}/scripts/run_wechat_archive_agent.sh"
bash -n "${SKILL_DIR}/scripts/run_wechat_archive_daily_index.sh"
bash -n "${SKILL_DIR}/scripts/run_wechat_archive_http_service.sh"
python3 -m py_compile "${SKILL_DIR}/scripts/archive_locator.py"

echo "selftest passed: wechat-archive safe checks"
