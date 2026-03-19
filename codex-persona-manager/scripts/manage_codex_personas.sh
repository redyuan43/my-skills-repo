#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ASSETS_DIR="${SKILL_DIR}/assets/personas"
CODEX_DIR="${HOME}/.codex"
CLAUDE_DIR="${HOME}/.claude"
OPENCODE_DIR="${HOME}/.config/opencode"

CODEX_PERSONAS_DIR="${CODEX_DIR}/personas"
CODEX_BACKUP_DIR="${CODEX_DIR}/persona-backups"
CODEX_TARGET_FILE="${CODEX_DIR}/AGENTS.md"
CODEX_HELPER_FILE="${CODEX_DIR}/use-persona"

CLAUDE_STYLES_DIR="${CLAUDE_DIR}/output-styles"
CLAUDE_BACKUP_DIR="${CLAUDE_DIR}/persona-backups"
CLAUDE_SETTINGS_FILE="${CLAUDE_DIR}/settings.json"

OPENCODE_PERSONAS_DIR="${OPENCODE_DIR}/personas"
OPENCODE_BACKUP_DIR="${OPENCODE_DIR}/persona-backups"
OPENCODE_TARGET_FILE="${OPENCODE_DIR}/AGENTS.md"

declare -a PERSONA_IDS=(
  "cat-kibble-engineer"
  "cat-cool-engineer"
  "cat-spoiled-engineer"
  "cat-sharp-tongue-engineer"
  "cat-maid-engineer"
  "cat-tsundere-engineer"
  "cat-soft-engineer"
  "cat-chief-engineer"
  "cat-playful-engineer"
  "cat-nightwatch-engineer"
)

TARGET="all"

persona_label() {
  case "$1" in
    cat-kibble-engineer) echo "幽浮喵 | 猫粮风 | 最像浮浮酱" ;;
    cat-cool-engineer) echo "霜岚喵 | 高冷风 | 决策审阅" ;;
    cat-spoiled-engineer) echo "蜜桃喵 | 撒娇风 | 陪伴协作" ;;
    cat-sharp-tongue-engineer) echo "赤练喵 | 毒舌风 | 排障纠偏" ;;
    cat-maid-engineer) echo "月见喵 | 女仆风 | 关照细致" ;;
    cat-tsundere-engineer) echo "凛铃喵 | 傲娇风 | 救火修复" ;;
    cat-soft-engineer) echo "糯米喵 | 软萌风 | 温和讲解" ;;
    cat-chief-engineer) echo "苍曜喵 | 总工风 | 架构评审" ;;
    cat-playful-engineer) echo "星糖喵 | 活泼风 | 前端创意" ;;
    cat-nightwatch-engineer) echo "夜墨喵 | 守夜风 | 运维安全" ;;
    *) echo "$1" ;;
  esac
}

backup_file() {
  local source_file="$1"
  local backup_dir="$2"
  local prefix="$3"

  mkdir -p "${backup_dir}"
  if [[ -f "${source_file}" ]]; then
    cp "${source_file}" "${backup_dir}/${prefix}.$(date +%Y%m%d-%H%M%S)"
  fi
}

install_codex_helper_script() {
  cat > "${CODEX_HELPER_FILE}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

PERSONA_NAME="${1:-}"
CODEX_DIR="${HOME}/.codex"
PERSONAS_DIR="${CODEX_DIR}/personas"
TARGET_FILE="${CODEX_DIR}/AGENTS.md"
BACKUP_DIR="${CODEX_DIR}/persona-backups"

if [[ -z "${PERSONA_NAME}" ]]; then
  echo "用法: ${0} <persona-id>"
  echo "可用人格:"
  find "${PERSONAS_DIR}" -maxdepth 1 -type f -name "*.md" -printf "%f\n" | sed 's/\.md$//' | sort
  exit 1
fi

SOURCE_FILE="${PERSONAS_DIR}/${PERSONA_NAME}.md"
if [[ ! -f "${SOURCE_FILE}" ]]; then
  echo "未找到人格: ${PERSONA_NAME}"
  echo "可用人格:"
  find "${PERSONAS_DIR}" -maxdepth 1 -type f -name "*.md" -printf "%f\n" | sed 's/\.md$//' | sort
  exit 1
fi

mkdir -p "${BACKUP_DIR}"
if [[ -f "${TARGET_FILE}" ]]; then
  cp "${TARGET_FILE}" "${BACKUP_DIR}/AGENTS.$(date +%Y%m%d-%H%M%S).md"
fi

cp "${SOURCE_FILE}" "${TARGET_FILE}"
echo "已切换 Codex 人格: ${PERSONA_NAME}"
echo "生效文件: ${TARGET_FILE}"
EOF
  chmod +x "${CODEX_HELPER_FILE}"
}

install_codex_personas() {
  mkdir -p "${CODEX_PERSONAS_DIR}" "${CODEX_BACKUP_DIR}"
  cp "${ASSETS_DIR}/"*.md "${CODEX_PERSONAS_DIR}/"
  install_codex_helper_script
}

install_claude_personas() {
  mkdir -p "${CLAUDE_STYLES_DIR}" "${CLAUDE_BACKUP_DIR}"
  cp "${ASSETS_DIR}/"*.md "${CLAUDE_STYLES_DIR}/"
}

install_opencode_personas() {
  mkdir -p "${OPENCODE_PERSONAS_DIR}" "${OPENCODE_BACKUP_DIR}"
  cp "${ASSETS_DIR}/"*.md "${OPENCODE_PERSONAS_DIR}/"
}

install_targets() {
  case "${TARGET}" in
    codex)
      install_codex_personas
      ;;
    claude)
      install_claude_personas
      ;;
    opencode)
      install_opencode_personas
      ;;
    all)
      install_codex_personas
      install_claude_personas
      install_opencode_personas
      ;;
    *)
      echo "不支持的 target: ${TARGET}" >&2
      exit 1
      ;;
  esac
}

list_personas() {
  local i=1
  for persona_id in "${PERSONA_IDS[@]}"; do
    printf "%2d. %-26s %s\n" "${i}" "${persona_id}" "$(persona_label "${persona_id}")"
    i=$((i + 1))
  done
}

activate_codex_persona() {
  local persona_id="$1"
  local source_file="${CODEX_PERSONAS_DIR}/${persona_id}.md"

  if [[ ! -f "${source_file}" ]]; then
    echo "未找到 Codex 人格模板: ${persona_id}" >&2
    exit 1
  fi

  backup_file "${CODEX_TARGET_FILE}" "${CODEX_BACKUP_DIR}" "AGENTS.md"
  cp "${source_file}" "${CODEX_TARGET_FILE}"
  echo "已激活 Codex 人格: ${persona_id}"
  echo "角色信息: $(persona_label "${persona_id}")"
  echo "生效文件: ${CODEX_TARGET_FILE}"
}

activate_claude_persona() {
  local persona_id="$1"
  local source_file="${CLAUDE_STYLES_DIR}/${persona_id}.md"

  if [[ ! -f "${source_file}" ]]; then
    echo "未找到 Claude Code 输出风格模板: ${persona_id}" >&2
    exit 1
  fi

  backup_file "${CLAUDE_SETTINGS_FILE}" "${CLAUDE_BACKUP_DIR}" "settings.json"
  python3 - <<PY
import json
from pathlib import Path

path = Path("${CLAUDE_SETTINGS_FILE}")
path.parent.mkdir(parents=True, exist_ok=True)
if path.exists():
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)
else:
    data = {}
data["outputStyle"] = "${persona_id}"
with path.open("w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
  echo "已激活 Claude Code 输出风格: ${persona_id}"
  echo "角色信息: $(persona_label "${persona_id}")"
  echo "生效文件: ${CLAUDE_SETTINGS_FILE}"
}

activate_opencode_persona() {
  local persona_id="$1"
  local source_file="${OPENCODE_PERSONAS_DIR}/${persona_id}.md"

  if [[ ! -f "${source_file}" ]]; then
    echo "未找到 OpenCode 人格模板: ${persona_id}" >&2
    exit 1
  fi

  backup_file "${OPENCODE_TARGET_FILE}" "${OPENCODE_BACKUP_DIR}" "AGENTS.md"
  mkdir -p "${OPENCODE_DIR}"
  cp "${source_file}" "${OPENCODE_TARGET_FILE}"
  echo "已激活 OpenCode 人格: ${persona_id}"
  echo "角色信息: $(persona_label "${persona_id}")"
  echo "生效文件: ${OPENCODE_TARGET_FILE}"
}

activate_persona() {
  local persona_id="$1"
  case "${TARGET}" in
    codex)
      activate_codex_persona "${persona_id}"
      ;;
    claude)
      activate_claude_persona "${persona_id}"
      ;;
    opencode)
      activate_opencode_persona "${persona_id}"
      ;;
    all)
      activate_codex_persona "${persona_id}"
      activate_claude_persona "${persona_id}"
      activate_opencode_persona "${persona_id}"
      ;;
    *)
      echo "不支持的 target: ${TARGET}" >&2
      exit 1
      ;;
  esac
}

choose_target_interactively() {
  local choice
  cat <<'EOF'
请选择要配置到哪个工具：
  1. Codex
  2. Claude Code
  3. OpenCode
  4. 全部
EOF
  read -r -p "请输入编号并回车 [默认 4]: " choice
  case "${choice:-4}" in
    1) TARGET="codex" ;;
    2) TARGET="claude" ;;
    3) TARGET="opencode" ;;
    4) TARGET="all" ;;
    *)
      echo "输入无效。" >&2
      exit 1
      ;;
  esac
}

interactive_select() {
  local choice persona_id

  choose_target_interactively
  install_targets

  echo "可选猫系人格："
  list_personas
  echo
  read -r -p "请输入编号并回车: " choice

  if [[ ! "${choice}" =~ ^[0-9]+$ ]]; then
    echo "输入无效，需要数字编号。" >&2
    exit 1
  fi

  if (( choice < 1 || choice > ${#PERSONA_IDS[@]} )); then
    echo "编号超出范围。" >&2
    exit 1
  fi

  persona_id="${PERSONA_IDS[$((choice - 1))]}"
  activate_persona "${persona_id}"
}

usage() {
  cat <<'EOF'
用法:
  bash scripts/manage_codex_personas.sh
  bash scripts/manage_codex_personas.sh --list
  bash scripts/manage_codex_personas.sh --install-only
  bash scripts/manage_codex_personas.sh --target <codex|claude|opencode|all> --activate <persona-id>

默认行为:
  先让你选择目标工具，再安装/更新人格模板并交互式列出人格供选择。
EOF
}

main() {
  local activate_id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --list)
        list_personas
        return 0
        ;;
      --install-only)
        install_targets
        echo "已安装/更新人格模板，目标: ${TARGET}"
        return 0
        ;;
      --target)
        if [[ $# -lt 2 ]]; then
          echo "缺少 target 参数" >&2
          usage
          exit 1
        fi
        TARGET="$2"
        shift 2
        ;;
      --activate)
        if [[ $# -lt 2 ]]; then
          echo "缺少 persona-id" >&2
          usage
          exit 1
        fi
        activate_id="$2"
        shift 2
        ;;
      -h|--help)
        usage
        return 0
        ;;
      *)
        echo "未知参数: $1" >&2
        usage
        exit 1
        ;;
    esac
  done

  if [[ -n "${activate_id}" ]]; then
    install_targets
    activate_persona "${activate_id}"
    return 0
  fi

  interactive_select
}

main "$@"
