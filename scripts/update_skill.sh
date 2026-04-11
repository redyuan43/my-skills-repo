#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
SYNC_SCRIPT="${REPO_ROOT}/sync-latest-skills/scripts/sync_latest_skills.sh"

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

[[ -d "${REPO_ROOT}/.git" ]] || die "not a git repo: ${REPO_ROOT}"
[[ -x "${SYNC_SCRIPT}" || -f "${SYNC_SCRIPT}" ]] || die "missing sync script: ${SYNC_SCRIPT}"

exec bash "${SYNC_SCRIPT}" --repo "${REPO_ROOT}" --rebase "$@"
