#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "" ]; then
  echo "Usage: md_to_longpng.sh <input.md> [output.png]" >&2
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

if ! command -v google-chrome >/dev/null 2>&1; then
  echo "google-chrome not found. Playwright needs the system Chrome channel." >&2
  exit 1
fi

input="$(realpath "$input")"
base="$(basename "$input" .md)"
srcdir="$(dirname "$input")"

if [ "$output" = "" ]; then
  output="$srcdir/${base}_long.png"
fi
output="$(realpath -m "$output")"
mkdir -p "$(dirname "$output")"

workdir="$(mktemp -d "${TMPDIR:-/tmp}/md-longpng.XXXXXX")"
cleanup() {
  rm -rf "$workdir"
}
trap cleanup EXIT

mkdir -p "$workdir/html"
cd "$srcdir"

npx --yes mume-cli html "$(basename "$input")" -o "$workdir/html"

html="$(find "$workdir/html" -type f -name '*.html' -print -quit)"
if [ "$html" = "" ]; then
  echo "HTML output not found under: $workdir/html" >&2
  exit 1
fi

html_with_base="$workdir/html/with-base.html"
base_href="file://$srcdir/"
awk -v base_href="$base_href" '
  BEGIN { inserted = 0 }
  /<head[^>]*>/ && inserted == 0 {
    print
    print "  <base href=\"" base_href "\">"
    inserted = 1
    next
  }
  { print }
' "$html" > "$html_with_base"

npx --yes playwright screenshot \
  --channel chrome \
  --full-page \
  --viewport-size=1280,900 \
  "file://$html_with_base" \
  "$output"

echo "$output"
