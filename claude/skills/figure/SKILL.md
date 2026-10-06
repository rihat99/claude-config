---
name: figure
description: Draw a static figure or schematic (method overview, pipeline, block diagram, timeline, comparison, teaser) as clean hand-written SVG, or as a draw.io file when the user wants to edit it later; render it to PNG/PDF and inspect the result. Use when the user asks for a figure, schematic, diagram, illustration or sketch for a paper, slides, README, poster or report. For interactive HTML system maps use archify; for data plots use matplotlib; for a whole page use explain-html.
---

# Figures: minimal, elegant, verified

A good figure has few elements, one visual idea, and labels that make the caption almost unnecessary. Draw it as SVG by hand so it is deterministic, editable and crisp at any size.

## 1. Plan in text first

Before drawing, write down:
- **Message**: the one sentence the figure must make obvious.
- **Elements**: every box, arrow and label, with its text. If the list has more than ~9 shapes, split into two figures or group into containers.
- **Flow**: reading direction (left→right or top→bottom) and the single main path. Side paths are lighter.
- **Size**: where it goes (single column ≈ 85 mm wide, double column ≈ 175 mm, a slide ≈ 300 mm) and therefore the minimum text size (≥ 8 pt in print, ≥ 18 pt on slides).

Ask the user when the message or the elements are unclear.

## 2. Style rules

- Grid: all coordinates multiples of 8 (or 10). Equal box sizes within a role; equal gaps.
- Shapes: rectangles with small radius (4–6), 1.5 px strokes, no 3D, no shadows, no gradients.
- Colors: dark gray text and strokes (`#1f2328`), light fills (`#f3f5f8`), **one** accent (`#1f6feb` or the document's accent) for the single most important element or path. A second color only when it encodes a category used consistently.
- Text: one sans-serif family (`Helvetica, Arial, sans-serif`), ≤ 3 sizes (title/label/annotation). Labels inside shapes, centered; never rotated unless on an axis.
- Arrows: one marker definition, 1.5 px, straight or single-elbow lines; arrows never cross if it can be avoided; arrowheads sit on the shape border, not inside it.
- Whitespace: inner padding ≥ 12 px, outer margin ≥ 16 px, nothing touches the `viewBox` edge.
- No decorative icons, clip art or emoji. A small icon only when it replaces a word.

## 3. SVG conventions

- Set `viewBox` and `width`/`height` in px; use presentation attributes (`fill=`, `stroke=`) rather than CSS classes so every converter and editor understands the file.
- Define reusable parts in `<defs>` (arrow marker, a `<symbol>` for repeated blocks).
- Put each logical group in a `<g>` with an `id` and a comment.
- Fonts: `font-family="Helvetica, Arial, sans-serif"`; for figures going into a LaTeX document you may use `font-family="Latin Modern Sans, Helvetica, Arial, sans-serif"`.
- Start from `templates/example.svg`.

## 4. draw.io

Only when the user asks for an editable draw.io file: write the `.drawio` XML by hand with the same style rules (use `rounded=1;whiteSpace=wrap;strokeWidth=1.5` style strings, few colors), then export with `drawio --export --format png --scale 3 file.drawio` (macOS; on Linux say the export must be done elsewhere) and inspect.

## 5. Render and inspect (always)

```bash
bash ~/.claude/skills/figure/scripts/render.sh figure.svg          # → figure.png (3x) and figure.pdf when a PDF converter exists
```

Open the PNG with the Read tool and check against this list, then fix and re-render:
- Nothing clipped at the edges; the `viewBox` has margin on all sides.
- No overlapping text, no text spilling out of its box, no arrow passing through a label.
- Arrowheads visible and pointing at the right thing; consistent stroke widths.
- Alignment: boxes in a row share top edges; gaps are equal; the main path reads in one direction.
- Text size readable at the final size (zoom out mentally to the print width).
- One accent color, used once or for one path only.

If no renderer exists on this machine the script says so; then tell the user the figure was not visually checked.

## 6. Deliver

Absolute paths to the `.svg` (source) and `.png`/`.pdf` (for inclusion). For LaTeX prefer the PDF; for slides and HTML the PNG at 3x or the SVG inline.
