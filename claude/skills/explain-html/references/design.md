# Design rules for explainer pages

Borrowed from what works in Archify's design system and from the common failures of generated pages.

## Layout

- One reading column, `max-width: 72ch`; figures and tables stay inside it (wide tables scroll inside their own box).
- Vertical rhythm: 1.5–2 rem between blocks, 3–4 rem between sections. Don't fill every pixel.
- Body 17 px (16 px on phones), line height 1.6. Headings: h1 2 rem, h2 1.4 rem, h3 1.1 rem, all with a tight line height (1.2).
- Narrow width (≤ 560 px): 16 px side gutters, no horizontal scroll, tables scroll inside their own box.

## Color

- Neutral ladder (`--bg`, `--surface`, `--border`, `--text`, `--muted`) plus **one** accent (`--accent`) for links, the active state and the single most important highlight.
- Semantic colors (`--ok`, `--warn`, `--bad`) only when the meaning is consistent across the whole page.
- Dark mode: same hierarchy, lower contrast surfaces, never pure black on pure white.
- Every saturated color must mean something. If swapping two colors would not change the meaning, remove one.

## Typography

- One family: the system stack (`-apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif`); monospace for code only.
- Hierarchy from size and weight, not from color or decoration.
- Headings are claims. "Smoothing removes 40 % of the jitter" beats "Results".
- Paragraphs ≤ 5 sentences, one idea each. Lists for parallel items only.

## Figures and tables

- Figure first appears where it is needed; caption below, one sentence that tells the reader what to see.
- Inline SVG, `viewBox` set, `width: 100%`, `max-width` fixed in px so it never blows up; text in the SVG ≥ 12 px at the rendered size; ink via `currentColor` and fills via the page's CSS variables so it works in both themes.
- Tables: header row bold, right-aligned numbers, units in the header, thin horizontal rules only, zebra striping optional.
- Big numbers (a KPI) get their own line with a small label; at most three per page.

## Avoid (these read as generated filler)

- Gradients, glassmorphism, drop shadows on everything, neon glows.
- Accent stripes, color bars, underlines beneath headings, rounded "cards" for every paragraph.
- Hero banners, emoji in headings, icons that don't carry information.
- Dense dashboards, grids of identical cards, more than one column of prose.
- Centered body text. Centered titles are fine.
- Animations that convey nothing. Transitions ≤ 200 ms, respect `prefers-reduced-motion`.

## Progressive disclosure

- The main path answers the question. Everything else goes inside `<details><summary>`.
- Code listings longer than ~25 lines: inside `<details>` with a one-line summary of what the code does.
- Links to source files as plain monospace paths, not buttons.

## Accessibility basics

- Contrast ≥ 4.5:1 for text in both themes.
- `alt` text on every image; SVG figures get a `<title>`.
- Keyboard reachable interactive parts, visible focus ring.
