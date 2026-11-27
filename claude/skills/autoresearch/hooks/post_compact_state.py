#!/usr/bin/env python3
"""SessionStart(compact) hook: after a compact, put this agent's task state
(agent_notes/tasks/<task_id>/STATE.md) plus one recovery sentence back into
context. Lean: the compact summary already carries the narrative, so only the
task's pointer file goes in, whole sections within AUTORESEARCH_STATE_MAX bytes
(default 6000, see trim_state).

The task is the folder this session last touched, kept in
~/.claude/autoresearch/task_<key>.json by hooks/context_watch.py on every tool
call. The compact protocol updates the task's STATE.md right before it queues
the compact, so a self-issued compact and a built-in auto-compact are restored
the same way. With no record, the task index (<git common dir>/autoresearch/
STATE.md, shared by all worktrees; see index_path) is injected and the agent is
told to find its task there. Inert outside research repos.
"""
import json
import os
import re
import subprocess
import sys
import time

TASK_DIR = os.path.join(os.path.expanduser("~"), ".claude", "autoresearch")
TASK_FRESH_S = 12 * 3600
STATE_MAX = int(os.environ.get("AUTORESEARCH_STATE_MAX", "6000"))
RECOVER = ("Re-invoke the `autoresearch` skill, read the file below and the files it "
           "points to, then resume from its 'Next steps'. The files, not your memory of "
           "the conversation, are the source of truth.")


def session_key():
    """Delivery key of this Claude session: j<job> for a background session
    (claude --bg / agent view: hosted by the daemon, no tmux pane of its own,
    $CLAUDE_JOB_DIR names its job), else p<pane> for a session in a tmux pane.
    A background session never uses an inherited $TMUX_PANE: that pane belongs
    to the session that spawned it."""
    job = os.path.basename(os.environ.get("CLAUDE_JOB_DIR", "").rstrip("/"))
    if job:
        return "j" + "".join(c for c in job if c.isalnum())
    pane = os.environ.get("TMUX_PANE", "").strip()
    return "p" + "".join(c for c in pane if c.isalnum()) if pane else ""


def research_repo(start):
    d = os.path.realpath(start)
    while True:
        if os.path.isdir(os.path.join(d, "agent_notes")):
            return d
        parent = os.path.dirname(d)
        if parent == d:
            return None
        d = parent


def index_path(repo):
    """The shared task index. It lives in the git common dir, so the main
    checkout and all its worktrees (one per task) read and write one file
    and it never goes through git. agent_notes/STATE.md if not under git."""
    try:
        out = subprocess.run(["git", "-C", repo, "rev-parse", "--git-common-dir"],
                             stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                             universal_newlines=True, timeout=10)
        if out.returncode == 0 and out.stdout.strip():
            common = os.path.realpath(os.path.join(repo, out.stdout.strip()))
            return os.path.join(common, "autoresearch", "STATE.md")
    except (OSError, subprocess.SubprocessError):
        pass
    return os.path.join(repo, "agent_notes", "STATE.md")


def last_task():
    """Record of the task folder the main agent of this session last touched
    (hooks/context_watch.py): {"task": id, "dir": absolute folder or ""}, or {}."""
    key = session_key()
    if not key:
        return {}
    try:
        with open(os.path.join(TASK_DIR, "task_%s.json" % key)) as f:
            rec = json.load(f)
        if time.time() - float(rec.get("seen") or 0) <= TASK_FRESH_S:
            return rec
    except (OSError, ValueError):
        pass
    return {}


def read(path, cap=200000):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()[:cap]


def trim_state(text, budget):
    """Whole '## ' sections in file order within the budget; a legacy
    '## Compact message' section is skipped (it steered the summary already);
    sections that do not fit are named, never cut mid-sentence."""
    keep, omitted, used = [], [], 0
    for sec in re.split(r"(?m)^(?=## )", text):
        if not sec.strip():
            continue
        title = sec.splitlines()[0].lstrip("# ").strip()
        if title.lower().startswith("compact message"):
            continue
        if keep and used + len(sec) > budget:
            omitted.append(title)
            continue
        if len(sec) > budget:
            sec = sec[:budget] + "\n[section truncated]\n"
        keep.append(sec)
        used += len(sec)
    out = "".join(keep)
    if omitted:
        out += "\n[omitted for size, read the file for: %s]\n" % ", ".join(omitted)
    return out


def main():
    data = json.load(sys.stdin)
    cwd = data.get("cwd") or os.getcwd()
    repo = research_repo(cwd)
    if not repo:
        return
    rec = last_task()
    tid = rec.get("task") or ""
    candidates = [os.path.join(rec.get("dir") or "", "STATE.md")] if rec.get("dir") else []
    if tid:
        candidates.append(os.path.join(repo, "agent_notes", "tasks", tid, "STATE.md"))
    task_state = next((c for c in candidates if os.path.isfile(c)), "")
    if task_state:
        parts = ["Compact done. " + RECOVER,
                 "--- %s (your task: the one you last touched before the compact) ---\n%s"
                 % (task_state, trim_state(read(task_state), STATE_MAX))]
    else:
        index = index_path(repo)
        why = (("task %s was recorded but has no STATE.md" % tid) if tid
               else "no task folder was touched in the last 12 h")
        parts = ["Compact done, and no record leads to your task's STATE.md (%s). Find your "
                 "task in the index below, read its agent_notes/tasks/<task_id>/STATE.md, "
                 "then: %s" % (why, RECOVER)]
        if os.path.isfile(index):
            parts.append("--- %s (task index; other agents' lines are not yours) ---\n%s"
                         % (index, read(index, 4000)))
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "SessionStart", "additionalContext": "\n\n".join(parts)}}))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print("post_compact_state: %s" % e, file=sys.stderr)
    sys.exit(0)
