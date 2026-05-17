#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "" ]; then
  echo "Usage: md_to_mobile_pdf.sh <input.md> [output.pdf] [title]" >&2
  exit 2
fi

input="$1"
output="${2:-}"
title="${3:-}"

if [ ! -f "$input" ]; then
  echo "Markdown file not found: $input" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "${PYTHON:-}" != "" ]; then
  python_bin="$PYTHON"
elif [ "${VIDEO_ANALYZER_ROOT:-}" != "" ] && [ -x "$VIDEO_ANALYZER_ROOT/.venv/bin/python" ]; then
  python_bin="$VIDEO_ANALYZER_ROOT/.venv/bin/python"
elif [ -x "/home/ivan/github/video-analyzer/.venv/bin/python" ]; then
  python_bin="/home/ivan/github/video-analyzer/.venv/bin/python"
elif [ -x "$PWD/.venv/bin/python" ]; then
  python_bin="$PWD/.venv/bin/python"
else
  python_bin="python3"
fi

input="$(realpath "$input")"
if [ "$output" = "" ]; then
  output="$(dirname "$input")/$(basename "$input" .md).mobile.pdf"
fi
output="$(realpath -m "$output")"
mkdir -p "$(dirname "$output")"

args=("$script_dir/md_to_mobile_pdf.py" "$input" "$output")
if [ "$title" != "" ]; then
  args+=("--title" "$title")
fi

"$python_bin" "${args[@]}"
