#!/usr/bin/env bash
# Render every page of a PDF to PNG with PyMuPDF from the shared venv.
# Usage: pdf_to_png.sh file.pdf [dpi]   → <file>_pages/page-NN.png (prints the paths)
PY="$HOME/.claude/venv/bin/python"
[ -x "$PY" ] || PY=python3
exec "$PY" - "$@" <<'PYEOF'
import os, sys
try:
    import pymupdf as fitz
except ImportError:
    try:
        import fitz
    except ImportError:
        sys.exit("pdf_to_png: PyMuPDF missing. Run ~/dotfiles/install.sh (creates ~/.claude/venv).")
if len(sys.argv) < 2:
    sys.exit("usage: pdf_to_png.sh file.pdf [dpi]")
pdf = os.path.abspath(sys.argv[1])
dpi = int(sys.argv[2]) if len(sys.argv) > 2 else 110
out_dir = os.path.splitext(pdf)[0] + "_pages"
os.makedirs(out_dir, exist_ok=True)
for old in os.listdir(out_dir):
    if old.startswith("page-") and old.endswith(".png"):
        os.remove(os.path.join(out_dir, old))
doc = fitz.open(pdf)
for i, page in enumerate(doc, 1):
    pix = page.get_pixmap(dpi=dpi)
    path = os.path.join(out_dir, "page-%02d.png" % i)
    pix.save(path)
    print(path)
print("== %d page(s) rendered at %d dpi" % (len(doc), dpi))
PYEOF
