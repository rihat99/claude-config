#!/usr/bin/env bash
# Screenshot an HTML file with headless Chrome at desktop and phone widths.
# Usage: render.sh page.html [--dark]   → page.desktop.png, page.phone.png (or page.dark.desktop.png …) next to the file
set -euo pipefail
[ $# -ge 1 ] || { echo "usage: render.sh page.html [--dark]" >&2; exit 2; }
PAGE=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
DARK=""; SUFFIX=""
[ "${2:-}" = "--dark" ] && { DARK="--force-dark-mode"; SUFFIX=".dark"; }
STEM="${PAGE%.html}$SUFFIX"

find_chrome() {
  for c in google-chrome google-chrome-stable chromium chromium-browser chrome; do
    command -v "$c" >/dev/null 2>&1 && { echo "$c"; return; }
  done
  for p in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
           "/Applications/Chromium.app/Contents/MacOS/Chromium" \
           "$HOME/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; do
    [ -x "$p" ] && { echo "$p"; return; }
  done
  return 1
}

CHROME=$(find_chrome) || { echo "render.sh: no Chrome/Chromium found; cannot screenshot. Validate the HTML by reading it and tell the user it was not viewed." >&2; exit 3; }

shoot() { # width height suffix
  local w=$1 h=$2 out="${STEM}.$3.png"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --no-sandbox $DARK \
    --window-size="$w,$h" --screenshot="$out" "file://$PAGE" >/dev/null 2>&1 || \
  "$CHROME" --headless --disable-gpu --hide-scrollbars --no-sandbox $DARK \
    --window-size="$w,$h" --screenshot="$out" "file://$PAGE" >/dev/null 2>&1
  echo "$out"
}

# Estimate page height so the screenshot covers the whole page (max 6000 px).
H=$("$CHROME" --headless=new --disable-gpu --no-sandbox --dump-dom "file://$PAGE" 2>/dev/null | wc -c | awk '{h=int($1/6)+800; if(h>6000)h=6000; if(h<900)h=900; print h}')
shoot 1280 "$H" desktop
shoot 420 "$H" phone
