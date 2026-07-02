#!/usr/bin/env bash
set -euo pipefail

host="${1:-github.com}"

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh is not installed." >&2
  exit 127
fi

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is not installed." >&2
  exit 127
fi

if [ -n "${GH_TOKEN:-}" ] || [ -n "${GITHUB_TOKEN:-}" ]; then
  echo "WARN: GH_TOKEN/GITHUB_TOKEN is set; it can override the stored gh credential." >&2
fi

if ! gh auth status --hostname "$host" >/dev/null 2>&1; then
  echo "GitHub CLI is not logged in for $host."
  echo "Complete the browser/device-code flow once; the token will be stored locally."
  printf 'Y\n' | gh auth login --hostname "$host" --git-protocol https --web
fi

gh config set git_protocol https --host "$host"
gh auth setup-git --hostname "$host"

echo
echo "GitHub CLI authentication:"
gh auth status --hostname "$host"

echo
echo "GitHub API user:"
gh api --hostname "$host" user --jq .login

echo
echo "Git credential config:"
git config --global --get-regexp '^credential\.' || true

echo
echo "Git credential helper smoke test:"
git credential fill <<EOF | sed -E 's/^password=.*/password=***MASKED***/'
protocol=https
host=$host

EOF
