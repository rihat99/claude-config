"""Small python-pptx helper that encodes the slides skill's rules.

16:9 canvas, one font family, one accent, big text, one visual per slide.
Every method adds one slide and returns it. Text limits are checked before the slide is
added, so a ValueError leaves the deck unchanged. Limits: title <= 10 words, all body text
on a slide <= max_words (20), <= 4 bullets, captions <= 15 words, tables <= 4 x 4.
Images are never upscaled: render visuals at >= 1600 px wide (the figure skill's 3x PNG).

    from deck import Deck
    d = Deck(accent="1F6FEB")
    d.title("Claim", "Name · Venue · Date")
    d.statement("Claim", image="fig.png", notes="what to say")
    d.save("/abs/talk.pptx")
"""
from __future__ import annotations

import os

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.util import Inches, Pt

W, H = Inches(13.333), Inches(7.5)
MARGIN = Inches(0.7)
TITLE_TOP = Inches(0.55)
TITLE_H = Inches(1.1)
BODY_TOP = Inches(1.9)
FONT = "Calibri"

SIZE_TITLE = Pt(36)
SIZE_BODY = Pt(26)
SIZE_SMALL = Pt(18)
SIZE_BIG = Pt(120)
SIZE_DECK_TITLE = Pt(44)

INK = RGBColor(0x1F, 0x23, 0x28)
MUTED = RGBColor(0x5B, 0x64, 0x70)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
DARK = RGBColor(0x14, 0x18, 0x1E)


def _rgb(hexstr: str) -> RGBColor:
    hexstr = hexstr.lstrip("#")
    return RGBColor(int(hexstr[0:2], 16), int(hexstr[2:4], 16), int(hexstr[4:6], 16))


class Deck:
    def __init__(self, accent: str = "1F6FEB", font: str = FONT, max_words: int = 20):
        self.prs = Presentation()
        self.prs.slide_width, self.prs.slide_height = W, H
        self.blank = self.prs.slide_layouts[6]
        self.accent = _rgb(accent)
        self.font = font
        self.max_words = max_words

    # ---- primitives -------------------------------------------------------
    def _slide(self, dark: bool = False):
        s = self.prs.slides.add_slide(self.blank)
        if dark:
            fill = s.background.fill
            fill.solid()
            fill.fore_color.rgb = DARK
        return s

    def _text(self, slide, left, top, width, height, text, size, bold=False,
              color=INK, align=PP_ALIGN.LEFT, anchor=MSO_ANCHOR.TOP, first_bold=False):
        """Add a text box. A list makes one paragraph per item; first_bold makes the first item a header."""
        box = slide.shapes.add_textbox(left, top, width, height)
        tf = box.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
        tf.vertical_anchor = anchor
        lines = text if isinstance(text, list) else [text]
        for i, line in enumerate(lines):
            p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
            p.alignment = align
            r = p.add_run()
            r.text = line
            r.font.name = self.font
            r.font.size = size
            r.font.bold = bold or (first_bold and i == 0)
            r.font.color.rgb = color
            if i > 0:
                p.space_before = Pt(10)
        return box

    def _title(self, slide, text, color=INK):
        return self._text(slide, MARGIN, TITLE_TOP, W - 2 * MARGIN, TITLE_H, text,
                          SIZE_TITLE, bold=True, color=color, anchor=MSO_ANCHOR.BOTTOM)

    def _picture(self, slide, path, left, top, max_w, max_h):
        if not os.path.isfile(path):
            raise FileNotFoundError(path)
        pic = slide.shapes.add_picture(path, left, top)
        scale = min(max_w / pic.width, max_h / pic.height, 1.0)  # shrink to fit, never enlarge
        pic.width, pic.height = int(pic.width * scale), int(pic.height * scale)
        pic.left = int(left + (max_w - pic.width) / 2)
        pic.top = int(top + (max_h - pic.height) / 2)
        return pic

    def _notes(self, slide, notes):
        if notes:
            slide.notes_slide.notes_text_frame.text = notes

    def _check_words(self, text, limit, what):
        words = len(" ".join(text if isinstance(text, list) else [text]).split())
        if words > limit:
            raise ValueError("%s has %d words (limit %d): %r" % (what, words, limit, text))

    def _check_image(self, path):
        if path and not os.path.isfile(path):
            raise FileNotFoundError(path)

    # ---- slide types --------------------------------------------------------
    def title(self, title: str, subtitle: str = "", notes: str = ""):
        self._check_words(title, 10, "title")
        self._check_words(subtitle, 12, "subtitle")
        s = self._slide(dark=True)
        self._text(s, MARGIN, Inches(2.4), W - 2 * MARGIN, Inches(1.8), title,
                   SIZE_DECK_TITLE, bold=True, color=WHITE, anchor=MSO_ANCHOR.BOTTOM)
        if subtitle:
            self._text(s, MARGIN, Inches(4.4), W - 2 * MARGIN, Inches(1.0), subtitle,
                       SIZE_BODY, color=RGBColor(0xC8, 0xCE, 0xD6))
        self._notes(s, notes)
        return s

    def section(self, title: str, notes: str = ""):
        self._check_words(title, 10, "section title")
        s = self._slide(dark=False)
        self._text(s, MARGIN, Inches(2.9), W - 2 * MARGIN, Inches(1.6), title,
                   SIZE_DECK_TITLE, bold=True, color=self.accent, anchor=MSO_ANCHOR.MIDDLE)
        self._notes(s, notes)
        return s

    def statement(self, title: str, text: str = "", image: str | None = None, notes: str = ""):
        """Claim on top, one visual (image) below; optional short line of text."""
        self._check_words(title, 10, "title")
        self._check_words(text, self.max_words, "body text")
        self._check_image(image)
        s = self._slide()
        self._title(s, title)
        top = BODY_TOP
        if text:
            self._text(s, MARGIN, top, W - 2 * MARGIN, Inches(0.9), text, SIZE_BODY, color=MUTED)
            top = top + Inches(1.0)
        if image:
            self._picture(s, image, MARGIN, top, W - 2 * MARGIN, H - top - Inches(0.5))
        self._notes(s, notes)
        return s

    def two_column(self, title: str, left: str | list, right: str | list | None = None,
                   right_image: str | None = None, notes: str = ""):
        """Text left; text or an image right. Both columns together stay within max_words."""
        self._check_words(title, 10, "title")
        self._check_words((left if isinstance(left, list) else [left]) + (right if isinstance(right, list) else [right or ""]),
                          self.max_words, "two columns")
        self._check_image(right_image)
        s = self._slide()
        self._title(s, title)
        col_w = (W - 2 * MARGIN - Inches(0.6)) / 2
        self._text(s, MARGIN, BODY_TOP, col_w, H - BODY_TOP - Inches(0.6), left, SIZE_BODY,
                   first_bold=isinstance(left, list))
        rx = MARGIN + col_w + Inches(0.6)
        if right_image:
            self._picture(s, right_image, rx, BODY_TOP, col_w, H - BODY_TOP - Inches(0.6))
        elif right:
            self._text(s, rx, BODY_TOP, col_w, H - BODY_TOP - Inches(0.6), right, SIZE_BODY,
                       first_bold=isinstance(right, list))
        self._notes(s, notes)
        return s

    def big_number(self, title: str, number: str, label: str, notes: str = ""):
        self._check_words(title, 10, "title")
        self._check_words(number, 3, "number")
        self._check_words(label, 12, "label")
        s = self._slide()
        self._title(s, title)
        self._text(s, MARGIN, Inches(2.3), W - 2 * MARGIN, Inches(2.6), number, SIZE_BIG,
                   bold=True, color=self.accent, align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
        self._text(s, MARGIN, Inches(5.0), W - 2 * MARGIN, Inches(0.9), label, SIZE_BODY,
                   color=MUTED, align=PP_ALIGN.CENTER)
        self._notes(s, notes)
        return s

    def image(self, title: str, path: str, caption: str = "", notes: str = ""):
        self._check_words(title, 10, "title")
        self._check_words(caption, 15, "caption")
        self._check_image(path)
        s = self._slide()
        self._title(s, title)
        bottom = Inches(0.5) + (Inches(0.6) if caption else 0)
        self._picture(s, path, MARGIN, BODY_TOP, W - 2 * MARGIN, H - BODY_TOP - bottom)
        if caption:
            self._text(s, MARGIN, H - Inches(1.0), W - 2 * MARGIN, Inches(0.5), caption,
                       SIZE_SMALL, color=MUTED, align=PP_ALIGN.CENTER)
        self._notes(s, notes)
        return s

    def bullets(self, title: str, items: list[str], image: str | None = None, notes: str = ""):
        """Up to 4 short bullets (no sub-bullets), optionally with an image on the right."""
        if len(items) > 4:
            raise ValueError("max 4 bullets, got %d" % len(items))
        self._check_words(title, 10, "title")
        self._check_words(items, self.max_words, "bullets")
        self._check_image(image)
        s = self._slide()
        self._title(s, title)
        width = (W - 2 * MARGIN - Inches(0.6)) / 2 if image else W - 2 * MARGIN
        self._text(s, MARGIN, BODY_TOP + Inches(0.2), width, H - BODY_TOP - Inches(0.8),
                   ["•  " + it for it in items], SIZE_BODY)
        if image:
            self._picture(s, image, MARGIN + width + Inches(0.6), BODY_TOP, width, H - BODY_TOP - Inches(0.6))
        self._notes(s, notes)
        return s

    def table(self, title: str, header: list[str], rows: list[list[str]], notes: str = ""):
        """A small table (<= 4 columns, <= 4 rows); first column left-aligned, the rest right-aligned."""
        if len(header) > 4 or len(rows) > 4:
            raise ValueError("table too big for a slide: max 4 columns and 4 rows")
        self._check_words(title, 10, "title")
        s = self._slide()
        self._title(s, title)
        n_rows, n_cols = len(rows) + 1, len(header)
        shape = s.shapes.add_table(n_rows, n_cols, MARGIN, BODY_TOP + Inches(0.3),
                                   W - 2 * MARGIN, Inches(0.7) * n_rows)
        tbl = shape.table
        for c, h in enumerate(header):
            self._cell(tbl.cell(0, c), h, bold=True, align=PP_ALIGN.LEFT if c == 0 else PP_ALIGN.RIGHT)
        for r, row in enumerate(rows, 1):
            for c, v in enumerate(row):
                self._cell(tbl.cell(r, c), v, align=PP_ALIGN.LEFT if c == 0 else PP_ALIGN.RIGHT)
        self._notes(s, notes)
        return s

    def _cell(self, cell, text, bold=False, align=PP_ALIGN.LEFT):
        cell.text = ""
        cell.fill.background()
        p = cell.text_frame.paragraphs[0]
        p.alignment = align
        r = p.add_run()
        r.text = str(text)
        r.font.name = self.font
        r.font.size = SIZE_BODY
        r.font.bold = bold
        r.font.color.rgb = INK

    def closing(self, title: str, text: str = "", notes: str = ""):
        self._check_words(title, 10, "title")
        self._check_words(text, 12, "closing text")
        s = self._slide(dark=True)
        self._text(s, MARGIN, Inches(2.6), W - 2 * MARGIN, Inches(1.6), title,
                   SIZE_DECK_TITLE, bold=True, color=WHITE, anchor=MSO_ANCHOR.BOTTOM)
        if text:
            self._text(s, MARGIN, Inches(4.4), W - 2 * MARGIN, Inches(1.0), text,
                       SIZE_BODY, color=RGBColor(0xC8, 0xCE, 0xD6))
        self._notes(s, notes)
        return s

    def save(self, path: str) -> str:
        path = os.path.abspath(path)
        self.prs.save(path)
        return path
