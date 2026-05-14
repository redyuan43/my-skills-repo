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
convert_input="$input"
convert_name="$name"
convert_base="$base"

if [ "$output" = "" ]; then
  output="$srcdir/$base.pdf"
fi
output="$(realpath -m "$output")"
mkdir -p "$(dirname "$output")"

cd "$srcdir"

mermaid_dir=""
mermaid_rendered=""
cleanup_mermaid() {
  if [ "$mermaid_rendered" != "" ] && [ -e "$mermaid_rendered" ]; then
    rm -f "$mermaid_rendered"
  fi
  if [ "$mermaid_dir" != "" ] && [ -d "$mermaid_dir" ]; then
    rm -rf "$mermaid_dir"
  fi
}

trap cleanup_mermaid EXIT

render_mermaid_blocks() {
  if ! grep -q '^```mermaid[[:space:]]*$' "$input"; then
    return 0
  fi

  mermaid_dir="$(mktemp -d "$srcdir/.${base}.mermaid.XXXXXX")"
  mermaid_rendered="$(mktemp "$srcdir/.${base}.rendered.XXXXXX.md")"

  local rendered="$mermaid_rendered"
  local assets_dir="$mermaid_dir/mermaid-assets"
  mkdir -p "$assets_dir"

  python3 - "$input" "$rendered" "$assets_dir" <<'PY'
from pathlib import Path
import re
import sys

source = Path(sys.argv[1])
target = Path(sys.argv[2])
assets = Path(sys.argv[3])
text = source.read_text(encoding="utf-8")
pattern = re.compile(r"(^```mermaid[ \t]*\n)(.*?)(^```[ \t]*$)", re.M | re.S)
parts = []
last = 0
count = 0
for match in pattern.finditer(text):
    count += 1
    parts.append(text[last:match.start()])
    stem = f"mermaid_{count:03d}"
    mmd = assets / f"{stem}.mmd"
    svg = assets / f"{stem}.svg"
    mmd.write_text(match.group(2).strip() + "\n", encoding="utf-8")
    rel_svg = svg.relative_to(target.parent).as_posix()
    parts.append(f"![Mermaid diagram {count}]({rel_svg})")
    last = match.end()
parts.append(text[last:])
target.write_text("".join(parts), encoding="utf-8")
PY

  local puppeteer_config="$mermaid_dir/puppeteer-config.json"
  cat > "$puppeteer_config" <<JSON
{
  "executablePath": "$chrome",
  "headless": true,
  "args": ["--no-sandbox", "--disable-setuid-sandbox", "--disable-dev-shm-usage", "--disable-gpu"]
}
JSON

  local mmd
  for mmd in "$assets_dir"/*.mmd; do
    timeout "${MERMAID_RENDER_TIMEOUT_SECONDS:-60}" \
      env PUPPETEER_EXECUTABLE_PATH="$chrome" \
      npx --yes @mermaid-js/mermaid-cli -q \
      -i "$mmd" \
      -o "${mmd%.mmd}.svg" \
      -b white \
      -p "$puppeteer_config"
  done

  convert_input="$rendered"
  convert_name="$(basename "$convert_input")"
  convert_base="${convert_name%.md}"
}

render_mermaid_blocks

generated="$(dirname "$convert_input")/$convert_base.pdf"
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
trap 'restore_backup; cleanup_mermaid' EXIT

PUPPETEER_EXECUTABLE_PATH="$chrome" npx --yes md-to-pdf "$convert_name"

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
