#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "" ]; then
  echo "Usage: md_to_pdf.sh <input.md> [output.pdf]" >&2
  exit 2
fi

export PATH="$HOME/.local/bin:$PATH"

input="$1"
output="${2:-}"

if [ ! -f "$input" ]; then
  echo "Markdown file not found: $input" >&2
  exit 1
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "npx not found. Install Node.js/npm or add npx to PATH." >&2
  exit 1
fi

chrome=""
for candidate in google-chrome google-chrome-stable chromium chromium-browser; do
  if command -v "$candidate" >/dev/null 2>&1; then
    chrome="$(command -v "$candidate")"
    break
  fi
done

if [ "$chrome" = "" ]; then
  echo "Chrome/Chromium not found. md-to-pdf requires a browser for Puppeteer." >&2
  exit 1
fi

input="$(realpath "$input")"
srcdir="$(dirname "$input")"
name="$(basename "$input")"
base="${name%.md}"

if [ "$output" = "" ]; then
  output="$srcdir/$base.pdf"
fi
output="$(realpath -m "$output")"
mkdir -p "$(dirname "$output")"

cd "$srcdir"

generated="$srcdir/$base.pdf"
backup=""
if [ -e "$generated" ] && [ "$generated" != "$output" ]; then
  backup="$(mktemp "${TMPDIR:-/tmp}/md-to-pdf-existing.XXXXXX.pdf")"
  mv "$generated" "$backup"
fi

restore_backup() {
  if [ "$backup" != "" ] && [ -e "$backup" ]; then
    mv "$backup" "$generated"
  fi
}
trap restore_backup EXIT

PUPPETEER_EXECUTABLE_PATH="$chrome" npx --yes md-to-pdf "$name"

if [ ! -s "$generated" ]; then
  echo "PDF output not found: $generated" >&2
  exit 1
fi

if [ "$generated" != "$output" ]; then
  mv "$generated" "$output"
fi

restore_backup
trap - EXIT

echo "$output"
