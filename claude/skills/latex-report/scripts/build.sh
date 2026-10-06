#!/usr/bin/env bash
# Compile a LaTeX file with tectonic, summarize warnings, render pages to PNG.
# Usage: build.sh report.tex [dpi]   → report.pdf, report_pages/page-NN.png
set -uo pipefail
[ $# -ge 1 ] || { echo "usage: build.sh report.tex [dpi]" >&2; exit 2; }
TEX=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
DIR=$(dirname "$TEX"); STEM=$(basename "${TEX%.tex}")
DPI="${2:-110}"
export PATH="$HOME/.local/bin:$PATH"
cd "$DIR"

ENGINE=""
if command -v tectonic >/dev/null 2>&1; then ENGINE=tectonic
elif command -v latexmk >/dev/null 2>&1; then ENGINE=latexmk
elif command -v pdflatex >/dev/null 2>&1; then ENGINE=pdflatex
else echo "build.sh: no LaTeX engine (tectonic/latexmk/pdflatex) found. Install tectonic: ~/claude-config/install.sh" >&2; exit 3; fi

LOG="$DIR/$STEM.build.log"
case "$ENGINE" in
  tectonic) tectonic --keep-logs --synctex=no "$TEX" >"$LOG" 2>&1; rc=$? ;;
  latexmk)  latexmk -pdf -interaction=nonstopmode "$TEX" >"$LOG" 2>&1; rc=$? ;;
  pdflatex) pdflatex -interaction=nonstopmode "$TEX" >"$LOG" 2>&1 && pdflatex -interaction=nonstopmode "$TEX" >>"$LOG" 2>&1; rc=$? ;;
esac

echo "== $ENGINE exit code: $rc  (full log: $LOG)"
TEXLOG="$DIR/$STEM.log"; [ -f "$TEXLOG" ] || TEXLOG="$LOG"
echo "== errors:";    grep -n -E '^! |Error' "$TEXLOG" | head -20 || true
echo "== overfull boxes:"; grep -c -E 'Overfull \\hbox' "$TEXLOG" 2>/dev/null | sed 's/^/   count: /'; grep -n -E 'Overfull \\hbox \([0-9.]+pt' "$TEXLOG" | awk -F'[()]' '{print "   " $0}' | sort -t'(' -k2 -rn | head -8 || true
echo "== undefined references / citations:"; grep -n -i -E 'undefined|Citation .* undefined|There were undefined' "$TEXLOG" | head -10 || true
echo "== other warnings:"; grep -n -E 'LaTeX Warning|Package .* Warning' "$TEXLOG" | grep -v -i -E 'undefined|rerun' | head -10 || true

[ "$rc" -eq 0 ] || exit "$rc"
PDF="$DIR/$STEM.pdf"
[ -f "$PDF" ] || { echo "build.sh: no PDF produced" >&2; exit 4; }
echo "== PDF: $PDF"
"$(dirname "$0")/pdf_to_png.py" "$PDF" "$DPI"
