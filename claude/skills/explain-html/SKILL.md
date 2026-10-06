---
name: explain-html
description: Build a single-file HTML page that explains a topic, a codebase, a method, results or a plan with a clear narrative, minimal design, inline SVG figures and light/dark support, then render it and look at it. Use only when the user asks for a web page, an HTML explainer, an interactive page, or "something I can open in a browser"; a question or a write-up without those words is answered in chat or as a latex-report. For a standalone interactive system map use archify; for slides use slides.
---

# Explain as an HTML page

One self-contained `.html` file, no build step, no framework. The reader should understand the main point in a minute and be able to go deeper without losing the thread.

## 1. Story before layout

Write (in the reply, briefly) before touching HTML:
- **Reader**: who opens this and what they already know.
- **The one question** the page answers, in one sentence. The page title is the answer, phrased as a claim.
- **Sections**: 3–7, each a step in the argument (problem → idea → how it works → evidence → limits → next). Each heading is a claim, not a label ("Contact forces come from the pose alone", not "Method").
- **Figures**: list each figure with the one thing the reader should see in it.

If the scope is unclear or the page would be long, ask before building.

## 2. Design rules

Read `references/design.md` once; the short version:
- One column, text width ≤ 72 characters, generous white space, 16–18 px body text, 1.6 line height.
- One font family (system stack), one accent color, neutral grays. Color only where it carries meaning.
- Flat surfaces, thin borders, no gradients, glass, shadows, decorative stripes, hero banners or emoji headings.
- Every figure sits where it is first needed and has a one-sentence caption that says what to look at.
- Numbers in tables, not in prose. Code in `<pre>` with a lead-in sentence.
- Deep dives inside `<details>`; the main path stays short.
- Light and dark via `prefers-color-scheme`; colors as CSS variables on `:root`.

Start from `templates/page.html`; it already encodes these rules.

## 3. Figures

- Draw figures as inline SVG following the `figure` skill (few elements, grid-aligned, labels inside shapes, one accent), but take ink and fills from the page's CSS variables (`stroke="currentColor"`, `fill="var(--surface)"`) so they stay visible in dark mode.
- For a real system / data-flow / sequence map, build it with the `archify` skill and link to its HTML file from the page (the page itself stays a single file).
- Data plots: render with matplotlib (the `~/.claude/venv/bin/python` env has it) to PNG at 2x, or write the chart as SVG by hand when it has fewer than ~30 points. Match the page's font and accent.

## 4. Build

- Single file: CSS and JS inline; only cdnjs.cloudflare.com for optional libraries (KaTeX for math, highlight.js for code). No tracking, no fonts from the network unless asked.
- Semantic HTML: `<header>`, `<main>`, `<section>`, `<figure>`/`<figcaption>`, `<table>` with `<th scope>`.
- Internal links for every section (`id` on headings) and a short table of contents when there are more than 4 sections.
- Interactivity only where it explains something (a slider that changes a parameter, tabs for alternatives). No animation for decoration.

## 5. Check it

```bash
bash ~/.claude/skills/explain-html/scripts/render.sh page.html        # desktop + narrow screenshots
```

The script shoots the whole page in light mode at 1280 px and at 500 px (Chrome's minimum window width; real phones are narrower, so keep the layout fluid) and splits tall pages into PNGs of 1600 px. Open every PNG with the Read tool and check: nothing clipped, text never wider than the column, figures readable at both widths, headings in order. Then run `render.sh page.html --dark` and check the dark PNGs the same way. Fix and re-render. If no browser is available the script says so; then read the HTML once more for mistakes and tell the user the page was not viewed.

## 6. Deliver

Give the absolute path. In the Claude desktop app with the Artifact tool available, publish the page as an artifact as well and give the link.
