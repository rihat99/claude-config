#!/usr/bin/env bash
# Render a .pptx to PDF (PowerPoint on macOS, LibreOffice elsewhere) and every slide to PNG.
# Usage: render.sh /abs/deck.pptx [dpi]   → deck.pdf, deck_pages/page-NN.png
set -uo pipefail
[ $# -ge 1 ] || { echo "usage: render.sh deck.pptx [dpi]" >&2; exit 2; }
IN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
DPI="${2:-80}"
PDF="${IN%.*}.pdf"
export PATH="$HOME/.local/bin:$PATH"
rm -f "$PDF"

if [ "$(uname -s)" = "Darwin" ] && [ -d "/Applications/Microsoft PowerPoint.app" ]; then
  osascript <<EOF >/dev/null 2>&1
tell application "Microsoft PowerPoint"
  open POSIX file "$IN"
  set thePres to active presentation
  save thePres in POSIX file "$PDF" as save as PDF
  close thePres saving no
end tell
EOF
  [ -f "$PDF" ] || echo "render.sh: PowerPoint export failed (grant automation permission to the terminal/Claude app if asked), trying LibreOffice…" >&2
fi

if [ ! -f "$PDF" ]; then
  SOFFICE=""
  for c in soffice libreoffice; do command -v "$c" >/dev/null 2>&1 && { SOFFICE="$c"; break; }; done
  [ -z "$SOFFICE" ] && [ -x "/Applications/LibreOffice.app/Contents/MacOS/soffice" ] && SOFFICE="/Applications/LibreOffice.app/Contents/MacOS/soffice"
  if [ -n "$SOFFICE" ]; then
    "$SOFFICE" --headless --convert-to pdf --outdir "$(dirname "$IN")" "$IN" >/dev/null 2>&1
  fi
fi

[ -f "$PDF" ] || { echo "render.sh: could not produce a PDF (no PowerPoint, no LibreOffice). Deck not visually checked." >&2; exit 3; }
echo "$PDF"
"$(dirname "$0")/pdf_to_png.py" "$PDF" "$DPI"
