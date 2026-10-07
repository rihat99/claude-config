#!/usr/bin/env python3
"""Insert the local delegation rule (claude/autoresearch/delegation.md) into the installed autoresearch skill.

The vendored installer copies upstream's SKILL.md and references/subagent_playbook.md fresh on
every install, so install.sh runs this right after it. The whole section goes into the playbook
(before "Aux agent"), its first paragraph into SKILL.md section 5. Both blocks sit between
markers and are replaced when already present, so editing delegation.md and reinstalling updates
them. Upstream's own text is never changed.
"""
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKILL = os.path.expanduser("~/.claude/skills/autoresearch")
BEGIN, END = "<!-- local:delegation -->", "<!-- /local:delegation -->"


def put_block(text, block, before_heading):
    """Replace an existing marker block, else insert `block` before `before_heading` (or at the end)."""
    if BEGIN in text and END in text:
        a = text.index(BEGIN)
        b = text.index(END) + len(END)
        return text[:a] + block + text[b:]
    i = text.find(before_heading)
    if i < 0:
        return text.rstrip("\n") + "\n\n" + block + "\n"
    return text[:i] + block + "\n\n" + text[i:]


def main():
    section = open(os.path.join(REPO, "claude", "autoresearch", "delegation.md")).read().strip()
    summary = section.split("\n\n")[1]  # the heading, then the one-paragraph rule
    playbook = os.path.join(SKILL, "references", "subagent_playbook.md")
    skill = os.path.join(SKILL, "SKILL.md")
    if not (os.path.isfile(playbook) and os.path.isfile(skill)):
        sys.exit("autoresearch skill not installed at %s" % SKILL)

    text = open(playbook).read()
    block = "%s\n%s\n%s" % (BEGIN, section, END)
    with open(playbook, "w") as f:
        f.write(put_block(text, block, "## Aux agent = full agent"))
    text = open(skill).read()
    block = "%s\nLocal rule (details: `references/subagent_playbook.md`, Delegation). %s\n%s" % (BEGIN, summary, END)
    with open(skill, "w") as f:
        f.write(put_block(text, block, "## 6. Talking to the user"))
    print("    autoresearch: local delegation rule in SKILL.md and subagent_playbook.md")


if __name__ == "__main__":
    main()
