#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN_SCRIPT="${ROOT_DIR}/scripts/reconcile_lmstudio_gui.sh"

test -f "${ROOT_DIR}/SKILL.md"
test -x "${MAIN_SCRIPT}" || chmod +x "${MAIN_SCRIPT}"

bash "${MAIN_SCRIPT}" status >/dev/null

for arch in x64 arm64; do
  url="https://lmstudio.ai/download/latest/linux/${arch}?format=AppImage"
  resolved="$(curl -fsSLI -o /dev/null -w '%{url_effective}\n' "${url}")"
  case "${resolved}" in
    *LM-Studio-*.AppImage)
      ;;
    *)
      printf 'Unexpected latest URL for %s: %s\n' "${arch}" "${resolved}" >&2
      exit 1
      ;;
  esac
done

printf 'selftest ok\n'
