#!/usr/bin/env python3
"""Stop + PostToolUse hook for research repos. State is keyed by this session:
p<pane> ($TMUX_PANE, e.g. %3 -> p3) in a tmux pane, j<job> ($CLAUDE_JOB_DIR)
for a background session, so several agents in the same repo do not touch each
other's state.

1. Task memory (PostToolUse, main agent): the task folder named in a tool call
   is recorded as this session's current task in
   ~/.claude/autoresearch/task_<key>.json; hooks/post_compact_state.py restores
   that task's STATE.md after a compact.
2. Context watch (Stop and PostToolUse), state in <repo>/.claude/autoresearch/:
   nudge the agent to run the compact
   protocol when session context exceeds AUTORESEARCH_CTX_LIMIT tokens
   (default 350000). Stop: blocks the stop with the nudge as reason.
   PostToolUse: injects the nudge as additionalContext mid-turn. One nudge per
   threshold crossing; re-nudges after AUTORESEARCH_CTX_STEP tokens of
   further growth. The dampener resets as soon as the context shrinks (a
   compact or /clear happened). State in ctx_<key>.json. A Stop with a compact
   already queued (self-compact skill) is never blocked: the delivery hook
   types the command once the turn has ended.
3. Subagent watch (PostToolUse with agent_id in the hook input): reads the
   subagent's own transcript; above AUTORESEARCH_SUB_CTX_LIMIT (default
   350000) tells it to write its state to its handoff file and return, so the
   main agent spawns a fresh successor (state in ctx_sub_<agent_id>.json).
   A subagent starts at ~20k (system prompt + tools) and is never nudged before
   it has grown AUTORESEARCH_SUB_MIN_GROWTH tokens (default 5000) past its
   first measurement, so a limit below the floor cannot livelock successors.
   Subagents never compact.

Jobs 2 and 3 are active only in research repos: the first directory from the
hook's cwd upwards that has agent_notes/ (the tracked shell cwd may sit in a
task folder or any subdirectory after a `cd`). Fails open on any error.
"""
import json
import os
import re
import sys
import time

LIMIT = int(os.environ.get("AUTORESEARCH_CTX_LIMIT", 350000))
SUB_LIMIT = int(os.environ.get("AUTORESEARCH_SUB_CTX_LIMIT", 350000))
SUB_MIN_GROWTH = int(os.environ.get("AUTORESEARCH_SUB_MIN_GROWTH", 5000))
STEP = int(os.environ.get("AUTORESEARCH_CTX_STEP", 40000))
TAIL_BYTES = 8 * 1024 * 1024
# Shared with hooks/post_compact_state.py: the task each session last touched.
TASK_DIR = os.path.join(os.path.expanduser("~"), ".claude", "autoresearch")
# The self-compact skill's request files (its scripts/request_compact.py, hooks/deliver.py).
COMPACT_DIR = os.path.join(os.path.expanduser("~"), ".claude", "self-compact")
COMPACT_TTL = int(os.environ.get("SELF_COMPACT_REQUEST_TTL", 600))

NUDGE = (
    "[context-watch] Session context is ~{ctx}k tokens (limit {limit}k). Do not "
    "start anything new. If you are mid-task, bring the current task to a clean "
    "stopping point first. Then run the autoresearch compact protocol "
    "(~/.claude/skills/autoresearch/references/compact_protocol.md): actualize "
    "artifacts, update your task's agent_notes/tasks/<task_id>/STATE.md (and your "
    "line in the task index), then queue the compact with "
    "~/.claude/skills/self-compact/scripts/request_compact.py \"/compact <msg>\" "
    "--then \"continue task <task_id>\" and end your reply. "
    "Fall back to asking the user to run it only if request_compact.py refuses."
)

SUB_NUDGE = (
    "[context-watch] Your context (subagent) is ~{ctx}k tokens (limit {limit}k). "
    "Do not start anything new. Write everything you have so far (results, "
    "state, what remains) to your handoff/scratch file (the path given in your "
    "task; otherwise agent_notes/tasks/<task_id>/subagents/<your_name>_state.md), "
    "then return to the main agent now with a short summary and that path. The "
    "main agent spawns a fresh successor from the file. Subagents never compact."
)


TASK_RE = re.compile(r"""((?:/[^\s"'\\]*)?)agent_notes/tasks/([A-Za-z0-9][A-Za-z0-9_.-]*)""")
TASK_REFRESH_S = 300


def remember_task(key, blob, cwd):
    """Record the task folder named in a tool call as this pane's current task
    (task_<key>.json), so the restore hook knows the
    task after any compact. Rewritten when it changes or is older than
    TASK_REFRESH_S, so a long task keeps a fresh record."""
    if "request_compact.py" in blob:
        return  # the compact message may name other tasks' files; it is not a touch
    hits = TASK_RE.findall(blob)
    if not hits:
        return
    prefix, task = hits[-1][0], hits[-1][1].rstrip(".")
    # the folder itself when the tool call gave an absolute path (a worktree outside the hook cwd)
    folder = os.path.join(prefix, "agent_notes", "tasks", task) if prefix.startswith("/") else ""
    path = os.path.join(TASK_DIR, "task_%s.json" % key)
    try:
        with open(path) as f:
            rec = json.load(f)
        if (rec.get("task") == task and rec.get("dir", "") == folder
                and time.time() - float(rec.get("seen") or 0) < TASK_REFRESH_S):
            return
    except (OSError, ValueError):
        pass
    try:
        os.makedirs(TASK_DIR, exist_ok=True)
        with open(path + ".tmp", "w") as f:
            json.dump({"task": task, "dir": folder, "cwd": cwd, "seen": time.time()}, f)
        os.replace(path + ".tmp", path)
    except OSError:
        pass


def research_repo(start):
    """First directory from `start` upwards that has agent_notes/, or None."""
    d = os.path.realpath(start)
    while True:
        if os.path.isdir(os.path.join(d, "agent_notes")):
            return d
        parent = os.path.dirname(d)
        if parent == d:
            return None
        d = parent


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


def compact_queued(key, cwd):
    """True if this session has a compact waiting for, or just handed to, the
    self-compact delivery hook (both hooks run on the same Stop, in any order)."""
    for d in (COMPACT_DIR, os.path.join(cwd, ".claude", "self-compact")):
        for name in ("compact_request_%s.json", "last_compact_request_%s.json"):
            try:
                with open(os.path.join(d, name % key)) as f:
                    created = float(json.load(f).get("created") or 0)
            except (OSError, ValueError):
                continue
            if time.time() - created <= COMPACT_TTL:
                return True
    return False


def context_tokens(transcript_path, sidechain=False):
    """Context of the last assistant turn. Main transcript: skip sidechain
    records (subagents). Subagent transcript (sidechain=True): all records are
    sidechain."""
    with open(transcript_path, "rb") as f:
        f.seek(0, 2)
        size = f.tell()
        f.seek(max(0, size - TAIL_BYTES))
        tail = f.read().decode("utf-8", "replace")
    for line in reversed(tail.splitlines()):
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except ValueError:
            continue
        if obj.get("isSidechain") and not sidechain:
            continue
        msg = obj.get("message") or {}
        usage = msg.get("usage") if isinstance(msg, dict) else None
        if obj.get("type") == "assistant" and isinstance(usage, dict):
            if (msg.get("model") or "").startswith("<"):
                continue
            return (usage.get("input_tokens", 0)
                    + usage.get("cache_read_input_tokens", 0)
                    + usage.get("cache_creation_input_tokens", 0))
    return None


def load_state(path, session_id):
    """State dict for this session; empty if the file belongs to another one."""
    try:
        with open(path) as f:
            state = json.load(f)
    except Exception:
        return {}
    return state if state.get("session_id") == session_id else {}


def save_state(path, session_id, **fields):
    state = load_state(path, session_id)
    state.update(fields, session_id=session_id)
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            json.dump(state, f)
    except Exception:
        pass


def nudge_once(state_path, sid, ctx, limit):
    """True if a nudge is due now: first crossing of `limit`, or +STEP since
    the last nudge. Context only shrinks when a compact (or /clear) happened,
    so a measurement below the last nudge point re-arms the watch."""
    last = load_state(state_path, sid).get("last_nudge_ctx", 0)
    if last and ctx < last:
        save_state(state_path, sid, last_nudge_ctx=0)
        last = 0
    if ctx > limit and ctx >= last + (STEP if last else 0):
        save_state(state_path, sid, last_nudge_ctx=ctx)
        return True
    return False


def watch_subagent(data, state_dir):
    """Subagent tool call: read the subagent's own transcript
    (<transcript dir>/<session_id>/subagents/agent-<id>.jsonl); above
    SUB_LIMIT tell it to hand off and return. Subagents never compact."""
    transcript, sid, aid = data.get("transcript_path"), data.get("session_id", ""), data["agent_id"]
    if not transcript:
        return
    sub = os.path.join(os.path.dirname(transcript), sid, "subagents", "agent-%s.jsonl" % aid)
    if not os.path.isfile(sub):
        return
    ctx = context_tokens(sub, sidechain=True)
    if ctx is None:
        return
    state_path = os.path.join(state_dir, "ctx_sub_%s.json" % aid)
    first = load_state(state_path, sid).get("first_ctx")
    if first is None:
        save_state(state_path, sid, first_ctx=ctx)
        first = ctx
    if ctx < first + SUB_MIN_GROWTH:
        return
    if nudge_once(state_path, sid, ctx, SUB_LIMIT):
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": data.get("hook_event_name") or "PostToolUse",
            "additionalContext": SUB_NUDGE.format(ctx=ctx // 1000, limit=SUB_LIMIT // 1000)}}))


def main():
    data = json.load(sys.stdin)
    cwd = data.get("cwd") or os.getcwd()
    event = data.get("hook_event_name") or "Stop"
    key = session_key()

    if event == "PostToolUse" and key and not data.get("agent_id"):
        remember_task(key, json.dumps(data.get("tool_input") or {}), cwd)

    if event == "Stop" and key and not data.get("agent_id") and compact_queued(key, cwd):
        return
    key = key or "nopane"

    repo = research_repo(cwd)
    if not repo:
        return
    state_dir = os.path.join(repo, ".claude", "autoresearch")
    if data.get("agent_id"):
        if event == "PostToolUse":
            watch_subagent(data, state_dir)
        return

    if event == "Stop" and data.get("stop_hook_active"):
        return

    transcript = data.get("transcript_path")
    if not transcript or not os.path.isfile(transcript):
        return
    ctx = context_tokens(transcript)
    if ctx is None:
        return

    if nudge_once(os.path.join(state_dir, "ctx_%s.json" % key), data.get("session_id", ""), ctx, LIMIT):
        nudge = NUDGE.format(ctx=ctx // 1000, limit=LIMIT // 1000)
        if event == "Stop":
            # decision/reason emitted both top-level and under hookSpecificOutput:
            # docs and observed behavior disagree on the shape; parsers ignore
            # whichever variant they don't know.
            print(json.dumps({
                "decision": "block", "reason": nudge,
                "hookSpecificOutput": {"hookEventName": "Stop",
                                       "decision": "block", "reason": nudge}}))
        else:
            print(json.dumps({"hookSpecificOutput": {
                "hookEventName": event, "additionalContext": nudge}}))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print("context_watch: %s" % e, file=sys.stderr)
    sys.exit(0)
