#!/usr/bin/env bash
# Render an SVG (or .drawio) figure to PNG (3x) and, when a converter exists, PDF.
# Usage: render.sh figure.svg [scale]     → figure.png, figure.pdf (if a PDF converter exists)
#        render.sh figure.drawio          → figure.png (+ .pdf) via the drawio CLI (macOS)
# Exit codes: 3 no renderer on this machine, 4 the renderer rejected the file (fix the SVG).
set -uo pipefail
[ $# -ge 1 ] || { echo "usage: render.sh figure.svg [scale]" >&2; exit 2; }
IN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
SCALE="${2:-3}"
STEM="${IN%.*}"
PNG="$STEM.png"; PDF="$STEM.pdf"
VENV_PY="$HOME/.claude/venv/bin/python"
ERR="$(mktemp)"

case "$IN" in
  *.drawio)
    command -v drawio >/dev/null 2>&1 || { echo "render.sh: drawio CLI not found on this machine; export the .drawio elsewhere." >&2; exit 3; }
    drawio --export --format png --scale "$SCALE" --output "$PNG" "$IN" >/dev/null 2>"$ERR" || { echo "render.sh: drawio export failed:" >&2; tail -3 "$ERR" >&2; exit 4; }
    drawio --export --format pdf --crop --output "$PDF" "$IN" >/dev/null 2>&1 || true
    echo "$PNG"; [ -f "$PDF" ] && echo "$PDF"; exit 0;;
esac

# resvg does not consult fontconfig aliases: on Linux tell it what "sans-serif" means here
FONT_ARGS=()
if [ "$(uname -s)" = "Linux" ] && command -v fc-match >/dev/null 2>&1; then
  fam="$(fc-match -f '%{family[0]}' sans-serif 2>/dev/null)"
  [ -n "$fam" ] && FONT_ARGS=(--sans-serif-family "$fam")
fi

rm -f "$PNG"
if command -v resvg >/dev/null 2>&1; then
  TOOL=resvg; resvg --zoom "$SCALE" "${FONT_ARGS[@]+"${FONT_ARGS[@]}"}" "$IN" "$PNG" 2>"$ERR"
elif command -v rsvg-convert >/dev/null 2>&1; then
  TOOL=rsvg-convert; rsvg-convert -z "$SCALE" -o "$PNG" "$IN" 2>"$ERR"
elif [ -x "$VENV_PY" ] && "$VENV_PY" -c "import cairosvg" 2>/dev/null; then
  TOOL=cairosvg; "$VENV_PY" -c "import cairosvg,sys; cairosvg.svg2png(url=sys.argv[1], write_to=sys.argv[2], scale=float(sys.argv[3]))" "$IN" "$PNG" "$SCALE" 2>"$ERR"
else
  echo "render.sh: no SVG renderer found (resvg, rsvg-convert, cairosvg). Figure not rendered; run ~/claude-config/install.sh." >&2; exit 3
fi
[ -s "$PNG" ] || { echo "render.sh: $TOOL could not render $IN (fix the SVG):" >&2; tail -5 "$ERR" >&2; rm -f "$ERR"; exit 4; }
grep -i 'warn\|no match' "$ERR" >&2 || true
echo "$PNG"

pdf_done=""
if command -v rsvg-convert >/dev/null 2>&1; then
  rsvg-convert -f pdf -o "$PDF" "$IN" 2>/dev/null && pdf_done=1
elif [ -x "$VENV_PY" ] && "$VENV_PY" -c "import cairosvg" 2>/dev/null; then
  "$VENV_PY" -c "import cairosvg,sys; cairosvg.svg2pdf(url=sys.argv[1], write_to=sys.argv[2])" "$IN" "$PDF" 2>/dev/null && pdf_done=1
elif command -v inkscape >/dev/null 2>&1; then
  inkscape "$IN" --export-type=pdf --export-filename="$PDF" >/dev/null 2>&1 && pdf_done=1
fi
rm -f "$ERR"
[ -n "$pdf_done" ] && echo "$PDF" || echo "render.sh: no SVG→PDF converter here (rsvg-convert, cairosvg, inkscape); include the 3x PNG instead." >&2
exit 0
