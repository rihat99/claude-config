---
name: slides
description: Make a presentation (.pptx) with a clear story, big visuals, very little text and one consistent elegant style; render every slide to PNG (PowerPoint on macOS, LibreOffice on Linux), look at them and fix what is wrong. Use when the user asks for slides, a deck, a talk, a presentation, or to improve an existing .pptx. For a document use latex-report; for a web page use explain-html.
---

# Slides

A slide is a visual with a claim on top. The detail lives in the speaker notes and in what the presenter says. Slides that need to be read are not slides.

## 1. Story first

Write the outline in the reply before building anything:
- **Audience and time slot** (a 10-minute talk is 8–12 slides; one slide per minute at most).
- **The one message** the audience must leave with.
- **Slide list**: each line is the slide's title *as a claim* ("Pose alone predicts contact force within 10 %"), plus the visual it shows. Section dividers only for talks longer than 15 slides.

Ask the user (with options) when the audience, the length or the main message is unclear, or when there are more than ~12 slides.

## 2. Rules

- **Text**: title ≤ 10 words (as a claim), all other text on the slide ≤ 20 words together. Never more than 4 bullets, never sub-bullets, never full sentences in bullets. Minimum 24 pt body, 36 pt titles; nothing below 18 pt, not even captions or axis labels. The helper below refuses slides that break these limits.
- **One visual per slide**: a figure (made with the `figure` skill), a plot, a photo, a big number, a short table (≤ 4 × 4). Text-only slides are allowed only as section dividers or the closing slide.
- **One style**: one font family (Calibri; Arial as fallback), one accent color, white background (or one solid dark color for the title and closing slide), consistent margins, titles always in the same place. Decide these once and never vary.
- **Never**: accent stripes or color bars, lines under titles, gradients, drop shadows, clip art, icons that carry no meaning, logos on every slide, animations, more than one chart per slide, more than one highlight color.
- **Numbers**: a single big number with a short label beats a table. Tables: ≤ 4 columns, numbers right-aligned.
- **Notes**: every content slide gets speaker notes with the full argument and the numbers behind it.
- **Consistency check** at the end: same title position, same font sizes, same accent, same margins on every slide.

## 3. Build

Use python-pptx through the helper, which encodes the rules (16:9, margins, sizes, layouts):

```python
import os, sys; sys.path.insert(0, os.path.expanduser("~/.claude/skills/slides/scripts"))
from deck import Deck
d = Deck(accent="1F6FEB")               # one accent for the whole deck
d.title("Talk title as a claim", "Name · Venue · Date")
d.section("Part 1")
d.statement("Pose alone predicts contact force within 10 %", image="figures/overview.png", notes="...")
d.two_column("Baseline vs ours", left=["Baseline", "12.3 mm error"], right_image="figures/ours.png")
d.big_number("Error drops by a third", "−34 %", "mean force error vs. baseline")
d.image("Qualitative results", "figures/qual.png", caption="Four held-out climbs")
d.table("Ours wins on both splits", ["Split", "Baseline", "Ours"], [["Seen", "12.3", "8.1"], ["Unseen", "15.0", "9.7"]])
d.bullets("What we learned", ["Pose is enough", "Contact timing matters", "Shoes are hard"], image="figures/summary.png")
d.closing("Pose alone predicts force", "github.com/you/project")
d.save("/abs/path/talk.pptx")
```

Run it with `~/.claude/venv/bin/python`. Every slide type takes `notes=`. `two_column` and `bullets` take an image for the right half; a slide with text on both sides is text-only and therefore wrong except as a divider. Images are never enlarged, so render visuals at 3× (≥ 1600 px wide). Existing decks or templates: open them with python-pptx (`Presentation(path)`) or, when the built-in `pptx` skill is listed in this session, follow its editing workflow. Never paste text as an image.

## 4. Render and inspect (always)

```bash
bash ~/.claude/skills/slides/scripts/render.sh /abs/path/talk.pptx     # → talk.pdf and talk_pages/page-NN.png
```

macOS exports a temporary copy through PowerPoint (first run may ask for automation permission; a deck you have open stays open), Linux through LibreOffice. Open every PNG with the Read tool and check: text inside its box, nothing overlapping, no slide with more than ~20 words, visuals large and centered, fonts and positions identical across slides, contrast readable. Fix the script, rebuild, re-render. On Linux fonts are substituted (Calibri → Carlito, same metrics), so fit is trustworthy.

If neither PowerPoint nor LibreOffice exists, say the deck was not visually checked.

## 5. Deliver

Absolute paths to the `.pptx`, the `.pdf` and the page PNGs; list which slides you changed after inspection.
