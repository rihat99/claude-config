---
name: latex-report
description: Write a report, technical note, lab write-up or paper-style document in LaTeX with a clean minimalist design, compile it with tectonic, render every page to PNG and check it. Use when the user asks for a LaTeX report, a PDF write-up, a paper draft, a technical document, or to turn notes and results into a printable report. For web pages use explain-html; for slides use slides.
---

# LaTeX report

The goal is a document a tired reader can follow in one pass: a clear argument, one idea per paragraph, figures and tables that carry the evidence, and a design that stays out of the way.

## 1. Agree the scope

Before writing, settle (ask with options when unclear): reader, purpose, length, required sections, which results and figures go in, page size (A4 unless told otherwise), and whether a specific template (conference class, course template) must be used. With a required class, keep its layout and apply only the writing rules below.

## 2. Structure

- Title, author, date. A **Summary** of 3–6 sentences: the question, what was done, the main result with a number, what it means.
- Sections follow the argument, not a form: problem → approach → what was done → results → discussion/limits → next steps. Rename to fit the content; headings may be claims.
- Each paragraph makes one point and starts with it. Lists for parallel items only.
- Figures and tables appear right after they are first mentioned and are referenced with `\cref`. Captions state the takeaway ("Error drops with more views"), not just the content.
- Tables with `booktabs` (no vertical rules), units in headers, numbers right-aligned with consistent decimals via `siunitx`.
- Equations only when needed; define every symbol the first time; number only equations you refer to.
- Code only when essential, short, in `lstlisting`/`minted` is not needed; use `verbatim` or a monospace block.

Read `references/writing.md` for the prose rules.

## 3. Design

Start from `templates/report.tex`: `article`, 11 pt, 1-inch margins, Latin Modern through `fontspec` (tectonic runs XeTeX, so Unicode such as −, µ, °, × prints as typed; the build summary lists any character the font lacks), `microtype`, numbered sections, compact headings, no colored boxes, no fancy headers or footers, subtle link colors, `parskip` spacing (no indent). Don't add packages for decoration. Numbers print as written: give each `S` column its own `table-format`, never a global rounding.

## 4. Figures

- Schematics: make them with the `figure` skill and include the PDF it produces; when its render script reports no PDF converter, include the 3x PNG instead.
- Plots: matplotlib with `~/.claude/venv/bin/python`; save as PDF; font size ≥ 8 pt at final width; one accent color; no chart junk (grid light or none, no top/right spines, no titles inside the plot when the caption says it).
- Width: `\linewidth` for single figures, `0.48\linewidth` side by side with `subcaption`.

## 5. Build and check

```bash
bash ~/.claude/skills/latex-report/scripts/build.sh report.tex      # tectonic + warning summary + page PNGs
```

The script compiles with tectonic (packages download on first use), prints a short summary of errors, missing characters, overfull boxes, undefined references and missing citations, and writes `report_pages/page-01.png` …. Open every page PNG with the Read tool and check: no overflow into the margin, no orphan heading at a page bottom, figures near their reference, tables within the text width, consistent fonts, no leftover placeholder text. Fix the source and rebuild until the summary is clean and the pages look right.

Bibliography: `natbib` with BibTeX (built into tectonic; `biber`/`biblatex` is not installed on these machines). Keep `references.bib` next to the `.tex` and uncomment the natbib lines in the template.

## 6. Deliver

Absolute paths to the PDF and the `.tex` folder. Mention anything not verified (for example when no page could be rendered).
