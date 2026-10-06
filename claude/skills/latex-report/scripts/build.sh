#!/usr/bin/env bash
# Compile a LaTeX file with tectonic (XeTeX), summarize problems, render pages to PNG.
# Usage: build.sh report.tex [dpi]   → report.pdf, report_pages/page-NN.png
set -uo pipefail
[ $# -ge 1 ] || { echo "usage: build.sh report.tex [dpi]" >&2; exit 2; }
TEX=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
DIR=$(dirname "$TEX"); STEM=$(basename "${TEX%.tex}")
DPI="${2:-110}"
export PATH="$HOME/.local/bin:$PATH"
cd "$DIR"

# the template uses fontspec, so the engine must be XeTeX-based
ENGINE=""
if command -v tectonic >/dev/null 2>&1 && tectonic --version >/dev/null 2>&1; then ENGINE=tectonic
elif command -v latexmk >/dev/null 2>&1 && command -v xelatex >/dev/null 2>&1; then ENGINE=latexmk
elif command -v xelatex >/dev/null 2>&1; then ENGINE=xelatex
else echo "build.sh: no working LaTeX engine (tectonic, or latexmk/xelatex) found. Install tectonic: bash ~/claude-config/install.sh" >&2; exit 3; fi

LOG="$DIR/$STEM.build.log"; TEXLOG="$DIR/$STEM.log"
rm -f "$TEXLOG"   # never read a stale log from an earlier run
case "$ENGINE" in
  tectonic) tectonic --keep-logs "$TEX" >"$LOG" 2>&1; rc=$? ;;
  latexmk)  latexmk -xelatex -interaction=nonstopmode "$TEX" >"$LOG" 2>&1; rc=$? ;;
  xelatex)  xelatex -interaction=nonstopmode "$TEX" >"$LOG" 2>&1 && xelatex -interaction=nonstopmode "$TEX" >>"$LOG" 2>&1; rc=$? ;;
esac
[ -f "$TEXLOG" ] || TEXLOG="$LOG"

echo "== $ENGINE exit code: $rc  (full log: $LOG)"
echo "== errors:"
{ grep -n -E '^! ' "$TEXLOG"; grep -n -E '^error:' "$LOG"; } | head -20
echo "== missing characters (the font cannot show them; fix the text or the font):"
grep -E 'Missing character' "$TEXLOG" | sed -E 's/^.*Missing character: There is no //' | sort | uniq -c | sort -rn | head -10
echo "== overfull boxes:"
printf '   count: %s\n' "$(grep -c -E 'Overfull \\hbox' "$TEXLOG")"
grep -n -E 'Overfull \\hbox \([0-9.]+pt' "$TEXLOG" | sed 's/^/   /' | head -8
echo "== undefined references / citations:"
grep -n -i -E 'undefined|Citation .* undefined|There were undefined' "$TEXLOG" | head -10
echo "== other warnings:"
grep -n -E 'LaTeX (Font )?Warning|Package .* Warning|Class .* Warning' "$TEXLOG" | grep -v -i -E 'undefined|rerun' | head -10

[ "$rc" -eq 0 ] || exit "$rc"
PDF="$DIR/$STEM.pdf"
[ -f "$PDF" ] || { echo "build.sh: no PDF produced" >&2; exit 4; }
echo "== PDF: $PDF"
"$(dirname "$0")/pdf_to_png.sh" "$PDF" "$DPI"
