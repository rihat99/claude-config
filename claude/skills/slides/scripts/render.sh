#!/usr/bin/env bash
# Render a .pptx to PDF (PowerPoint on macOS, LibreOffice elsewhere) and every slide to PNG.
# Usage: render.sh /abs/deck.pptx [dpi]   → deck.pdf, deck_pages/page-NN.png
# PowerPoint exports a temporary copy of the file, so a deck the user has open stays open and
# the PDF always reflects what is on disk.
set -uo pipefail
[ $# -ge 1 ] || { echo "usage: render.sh deck.pptx [dpi]" >&2; exit 2; }
IN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
DPI="${2:-80}"
PDF="${IN%.*}.pdf"
export PATH="$HOME/.local/bin:$PATH"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
rm -f "$PDF"   # our own output from a previous run
WHY=""

if [ "$(uname -s)" = "Darwin" ] && [ -d "/Applications/Microsoft PowerPoint.app" ]; then
  # fixed paths: sandboxed PowerPoint asks "grant access" once per new path, so a new temp dir would ask every run
  FIXED="$HOME/.cache/pptx-render"; mkdir -p "$FIXED"
  COPY="$FIXED/render-copy.pptx"; cp "$IN" "$COPY"; rm -f "$FIXED/render-copy.pdf"
  osascript - "$COPY" "$FIXED/render-copy.pdf" <<'EOF2' >/dev/null 2>"$TMP/osa.err"
on run argv
  set src to POSIX file (item 1 of argv)
  set dst to POSIX file (item 2 of argv)
  tell application "Microsoft PowerPoint"
    open src
    set thePres to active presentation
    if name of thePres is not (do shell script "basename " & quoted form of (item 1 of argv)) then error "opened the wrong presentation: " & (name of thePres)
    save thePres in dst as save as PDF
    close thePres saving no
  end tell
end run
EOF2
  if [ -s "$FIXED/render-copy.pdf" ]; then mv "$FIXED/render-copy.pdf" "$PDF"
  else WHY="PowerPoint: $(tail -1 "$TMP/osa.err" 2>/dev/null)"; echo "render.sh: PowerPoint export failed ($WHY); trying LibreOffice" >&2; fi
fi

if [ ! -f "$PDF" ]; then
  SOFFICE=""
  for c in soffice libreoffice; do command -v "$c" >/dev/null 2>&1 && { SOFFICE="$c"; break; }; done
  [ -z "$SOFFICE" ] && [ -x "/Applications/LibreOffice.app/Contents/MacOS/soffice" ] && SOFFICE="/Applications/LibreOffice.app/Contents/MacOS/soffice"
  if [ -n "$SOFFICE" ]; then
    perl -e 'alarm 240; exec @ARGV' "$SOFFICE" -env:UserInstallation="file://$TMP/profile" --headless --convert-to pdf \
      --outdir "$TMP" "$IN" >"$TMP/lo.log" 2>&1
    OUT="$TMP/$(basename "${IN%.*}").pdf"
    if [ -s "$OUT" ]; then mv "$OUT" "$PDF"; else WHY="$WHY${WHY:+; }LibreOffice: $(tail -1 "$TMP/lo.log" 2>/dev/null)"; fi
  else
    WHY="$WHY${WHY:+; }no LibreOffice"
  fi
fi

[ -f "$PDF" ] || { echo "render.sh: could not produce a PDF ($WHY). Deck not visually checked." >&2; exit 3; }
echo "$PDF"
"$(dirname "$0")/../../latex-report/scripts/pdf_to_png.sh" "$PDF" "$DPI"
