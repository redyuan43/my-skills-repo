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
chrome="$(command -v google-chrome)"

input="$(realpath "$input")"
base="$(basename "$input" .md)"
srcdir="$(dirname "$input")"
convert_input="$input"
convert_base="$base"

if [ "$output" = "" ]; then
  output="$srcdir/${base}_long.png"
fi
output="$(realpath -m "$output")"
mkdir -p "$(dirname "$output")"

workdir="$(mktemp -d "${TMPDIR:-/tmp}/md-longpng.XXXXXX")"
mermaid_dir=""
mermaid_rendered=""
cleanup() {
  rm -rf "$workdir"
  if [ "$mermaid_rendered" != "" ] && [ -e "$mermaid_rendered" ]; then
    rm -f "$mermaid_rendered"
  fi
  if [ "$mermaid_dir" != "" ] && [ -d "$mermaid_dir" ]; then
    rm -rf "$mermaid_dir"
  fi
}
trap cleanup EXIT

mkdir -p "$workdir/html"
cd "$srcdir"

render_mermaid_blocks() {
  if ! grep -q '^```mermaid[[:space:]]*$' "$input"; then
    return 0
  fi

  mermaid_dir="$(mktemp -d "$srcdir/.${base}.mermaid.XXXXXX")"
  mermaid_rendered="$(mktemp "$srcdir/.${base}.rendered.XXXXXX.md")"

  local assets_dir="$mermaid_dir/mermaid-assets"
  mkdir -p "$assets_dir"

  python3 - "$input" "$mermaid_rendered" "$assets_dir" <<'PY'
from pathlib import Path
import re
import sys

source = Path(sys.argv[1])
target = Path(sys.argv[2])
assets = Path(sys.argv[3])
text = source.read_text(encoding="utf-8")
pattern = re.compile(r"(^```mermaid[ \t]*\n)(.*?)(^```[ \t]*$)", re.M | re.S)

def normalize_mermaid(diagram: str) -> str:
    # Mermaid flowchart labels with parentheses or punctuation are safer quoted.
    return re.sub(
        r'(?<![\w])([A-Za-z][A-Za-z0-9_]*)\[([^"\]\n][^\]\n]*)\]',
        lambda m: f'{m.group(1)}["{m.group(2).replace(chr(34), chr(92) + chr(34))}"]',
        diagram,
    )

parts = []
last = 0
count = 0
for match in pattern.finditer(text):
    count += 1
    parts.append(text[last:match.start()])
    stem = f"mermaid_{count:03d}"
    mmd = assets / f"{stem}.mmd"
    svg = assets / f"{stem}.svg"
    mmd.write_text(normalize_mermaid(match.group(2).strip()) + "\n", encoding="utf-8")
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

  convert_input="$mermaid_rendered"
  convert_base="$(basename "$convert_input" .md)"
}

render_mermaid_blocks

npx --yes mume-cli html "$(basename "$convert_input")" -o "$workdir/html"

html="$(find "$workdir/html" -type f -name '*.html' -print -quit)"
if [ "$html" = "" ]; then
  echo "HTML output not found under: $workdir/html" >&2
  exit 1
fi

html_with_base="$workdir/html/with-base.html"
base_href="file://$srcdir/"
style_block=""
if [ "${LONGPNG_NO_MARGIN:-0}" = "1" ]; then
  padding="${LONGPNG_CONTENT_PADDING:-5}"
  style_block="<style>
html, body {
  margin: 0 !important;
  padding: 0 !important;
  width: 100% !important;
  background: #fff !important;
}
body {
  box-sizing: border-box !important;
}
.markdown-preview,
.mume,
body > div,
body > main {
  box-sizing: border-box !important;
  max-width: none !important;
  width: 100% !important;
  margin: 0 !important;
  padding: ${padding}px !important;
}
img, video, canvas, svg {
  max-width: 100% !important;
  height: auto;
}
</style>"
fi
awk -v base_href="$base_href" -v style_block="$style_block" '
  BEGIN { inserted = 0 }
  /<head[^>]*>/ && inserted == 0 {
    print
    print "  <base href=\"" base_href "\">"
    if (style_block != "") {
      print style_block
    }
    inserted = 1
    next
  }
  { print }
' "$html" > "$html_with_base"

npx --yes playwright screenshot \
  --channel chrome \
  --full-page \
  --viewport-size="${LONGPNG_VIEWPORT_SIZE:-1280,900}" \
  "file://$html_with_base" \
  "$output"

echo "$output"
