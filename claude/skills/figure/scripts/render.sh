#!/usr/bin/env bash
# Render an SVG (or .drawio) figure to PNG (3x) and, when possible, PDF.
# Usage: render.sh figure.svg [scale]     → figure.png, figure.pdf (if a PDF converter exists)
#        render.sh figure.drawio          → figure.png via the drawio CLI (macOS)
set -euo pipefail
[ $# -ge 1 ] || { echo "usage: render.sh figure.svg [scale]" >&2; exit 2; }
IN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
SCALE="${2:-3}"
STEM="${IN%.*}"
PNG="$STEM.png"; PDF="$STEM.pdf"
VENV_PY="$HOME/.claude/venv/bin/python"

case "$IN" in
  *.drawio)
    if command -v drawio >/dev/null 2>&1; then
      drawio --export --format png --scale "$SCALE" --output "$PNG" "$IN" >/dev/null 2>&1
      drawio --export --format pdf --crop --output "$PDF" "$IN" >/dev/null 2>&1 || true
      echo "$PNG"; [ -f "$PDF" ] && echo "$PDF"; exit 0
    fi
    echo "render.sh: drawio CLI not found on this machine; export the .drawio elsewhere." >&2; exit 3;;
esac

png_done=""
if command -v resvg >/dev/null 2>&1; then
  resvg --zoom "$SCALE" "$IN" "$PNG" && png_done=1
elif command -v rsvg-convert >/dev/null 2>&1; then
  rsvg-convert -z "$SCALE" -o "$PNG" "$IN" && png_done=1
elif [ -x "$VENV_PY" ] && "$VENV_PY" -c "import cairosvg" 2>/dev/null; then
  "$VENV_PY" -c "import cairosvg,sys; cairosvg.svg2png(url=sys.argv[1], write_to=sys.argv[2], scale=float(sys.argv[3]))" "$IN" "$PNG" "$SCALE" && png_done=1
elif command -v drawio >/dev/null 2>&1; then
  drawio --export --format png --scale "$SCALE" --output "$PNG" "$IN" >/dev/null 2>&1 && png_done=1
fi
[ -n "$png_done" ] || { echo "render.sh: no SVG renderer found (resvg, rsvg-convert, cairosvg, drawio). Figure not rendered." >&2; exit 3; }
echo "$PNG"

pdf_done=""
if command -v rsvg-convert >/dev/null 2>&1; then
  rsvg-convert -f pdf -o "$PDF" "$IN" && pdf_done=1
elif [ -x "$VENV_PY" ] && "$VENV_PY" -c "import cairosvg" 2>/dev/null; then
  "$VENV_PY" -c "import cairosvg,sys; cairosvg.svg2pdf(url=sys.argv[1], write_to=sys.argv[2])" "$IN" "$PDF" && pdf_done=1
elif command -v inkscape >/dev/null 2>&1; then
  inkscape "$IN" --export-type=pdf --export-filename="$PDF" >/dev/null 2>&1 && pdf_done=1
elif command -v drawio >/dev/null 2>&1; then
  drawio --export --format pdf --crop --output "$PDF" "$IN" >/dev/null 2>&1 && pdf_done=1
fi
[ -n "$pdf_done" ] && echo "$PDF" || echo "render.sh: no PDF converter; use the PNG (3x) for inclusion." >&2
exit 0
