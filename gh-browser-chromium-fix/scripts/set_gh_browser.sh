#!/usr/bin/env bash
set -euo pipefail

resolve_chromium() {
  local input="${1:-}"
  local candidate

  if [[ -n "$input" ]]; then
    if command -v "$input" >/dev/null 2>&1; then
      command -v "$input"
      return 0
    fi
    if [[ -x "$input" ]]; then
      printf '%s\n' "$input"
      return 0
    fi
    echo "Chromium executable not found or not executable: $input" >&2
    return 1
  fi

  for candidate in \
    "$HOME/.local/bin/chromium" \
    "$(command -v chromium 2>/dev/null || true)" \
    "$(command -v chromium-browser 2>/dev/null || true)" \
    "$(command -v google-chrome-stable 2>/dev/null || true)" \
    "$(command -v google-chrome 2>/dev/null || true)"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

chromium="$(resolve_chromium "${1:-}")" || {
  echo "No usable Chromium-style browser found." >&2
  exit 1
}

gh config set browser "$chromium"
xdg-mime default org.chromium.Chromium.desktop x-scheme-handler/http x-scheme-handler/https text/html
xdg-settings set default-web-browser org.chromium.Chromium.desktop 2>/dev/null || true

printf 'gh browser: %s\n' "$(gh config get browser)"
printf 'http handler: %s\n' "$(xdg-mime query default x-scheme-handler/http)"
printf 'https handler: %s\n' "$(xdg-mime query default x-scheme-handler/https)"
