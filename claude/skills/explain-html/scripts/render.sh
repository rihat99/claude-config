#!/usr/bin/env bash
# Screenshot an HTML file with headless Chrome at desktop (1280 px) and narrow (500 px, Chrome's
# minimum window width) widths, in light or dark mode, at full page height. Tall pages are split
# into PNGs of at most 1600 px so each one stays readable.
# Usage: render.sh page.html [--dark]   → page.desktop.png, page.phone.png  (page.dark.*.png with --dark;
#                                         page.desktop-1.png, -2.png … when split)
set -uo pipefail
[ $# -ge 1 ] || { echo "usage: render.sh page.html [--dark]" >&2; exit 2; }
PAGE=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
# Blink's preferredColorScheme: 1 = light, 0 = dark. Without it headless Chrome follows the OS theme.
SCHEME="--blink-settings=preferredColorScheme=1"; SUFFIX=""
[ "${2:-}" = "--dark" ] && { SCHEME="--blink-settings=preferredColorScheme=0"; SUFFIX=".dark"; }
STEM="${PAGE%.html}$SUFFIX"
MAX_H=16000   # Chrome screenshot height limit (textures top out near 16384); taller pages are cut and reported
PY="$HOME/.claude/venv/bin/python"; [ -x "$PY" ] || PY=python3

find_chrome() {
  [ -n "${CHROME:-}" ] && [ -x "$CHROME" ] && { echo "$CHROME"; return; }
  for c in google-chrome google-chrome-stable chromium chromium-browser chrome chrome-headless-shell; do
    command -v "$c" >/dev/null 2>&1 && { command -v "$c"; return; }
  done
  for p in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
           "/Applications/Chromium.app/Contents/MacOS/Chromium" \
           "$HOME/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; do
    [ -x "$p" ] && { echo "$p"; return; }
  done
  return 1
}
CHROME=$(find_chrome) || { echo "render.sh: no Chrome/Chromium found (set CHROME=/path to override); cannot screenshot. Read the HTML instead and tell the user it was not viewed." >&2; exit 3; }

ERR="$(mktemp)"
shoot() { # width name
  local w=$1 out="${STEM}.$2.png"
  rm -f "$out"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --no-sandbox $SCHEME \
    --window-size="$w,$MAX_H" --screenshot="$out" "file://$PAGE" >/dev/null 2>"$ERR"
  [ -s "$out" ] || { echo "render.sh: Chrome ($CHROME) produced no screenshot:" >&2; tail -5 "$ERR" >&2; rm -f "$ERR"; exit 4; }
  "$PY" - "$out" 1600 "$MAX_H" <<'PYEOF'
import os, sys
src, max_h, limit = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
try:
    from PIL import Image
except ImportError:
    print(src); print("render.sh: Pillow missing, screenshot left untrimmed", file=sys.stderr); sys.exit(0)
im = Image.open(src).convert("RGB"); w, h = im.size; px = im.load()
bg = px[w - 1, h - 1]
last = h - 1
while last > 0 and all(px[x, last] == bg for x in range(0, w, 8)):
    last -= 1
if last >= h - 2:
    print("render.sh: page is taller than %d px; the bottom is cut off" % limit, file=sys.stderr)
im = im.crop((0, 0, w, min(h, last + 48))); h = im.size[1]
if h <= max_h:
    im.save(src); print(src)
else:
    base = src[:-4]; n = 0
    for top in range(0, h, max_h):
        n += 1; im.crop((0, top, w, min(h, top + max_h))).save("%s-%d.png" % (base, n)); print("%s-%d.png" % (base, n))
    os.remove(src)
PYEOF
}
shoot 1280 desktop
shoot 500 phone
rm -f "$ERR"
