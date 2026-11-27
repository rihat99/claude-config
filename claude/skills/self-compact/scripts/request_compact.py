#!/usr/bin/env python3
"""Agent-side: queue a /compact for the Stop hook to type into this session's terminal.

    python3 ~/.claude/skills/self-compact/scripts/request_compact.py "/compact <msg>"
    python3 ~/.claude/skills/self-compact/scripts/request_compact.py "/compact <msg>" --then "<text>"

Writes ~/.claude/self-compact/compact_request_<key>.json, keyed by this
session: p<pane> from $TMUX_PANE (e.g. %3 -> p3) for a session in a tmux pane,
j<job> from $CLAUDE_JOB_DIR for a background session (claude --bg / agent view,
which has no pane; an inherited $TMUX_PANE is ignored there). When the agent's
turn ends, the Stop hook (hooks/deliver.py) of the same session reads the file
and types the command into its terminal via tmux_deliver.py: into the pane, or
into a `claude attach` opened in a scratch tmux window.

The file is keyed by pane and kept under $HOME, not in the project, because
the hook's cwd is Claude Code's tracked shell cwd, which matches neither this
script's cwd nor the process cwd once the agent works in a worktree or a
subdirectory. If $HOME is not writable (Bash sandbox), the script falls back
to <cwd>/.claude/self-compact/ with a warning.

Only /compact and /clear are accepted, and the line is capped at MAX_CHARS:
the compact message is 1-2 sentences. --then TEXT is typed after the
compaction finishes, so the session resumes on its own; without it nothing
follows and the session waits for the user. --then may appear before or after
the command and is a plain message, it may not start with "/". The hook
discards requests older than SELF_COMPACT_REQUEST_TTL s (default 600): end the
reply right after queuing.
"""
import json
import os
import sys
import time

ALLOWED = ("/compact", "/clear")
MAX_CHARS = 800
# Shared with hooks/deliver.py: per-session request files + deliver.log.
REQUEST_DIR = os.path.join(os.path.expanduser("~"), ".claude", "self-compact")


def parse(argv):
    """Return (command, then). --then TEXT is accepted anywhere; everything
    else is joined into the command."""
    then, rest = "", []
    i = 0
    while i < len(argv):
        if argv[i] == "--then":
            if i + 1 >= len(argv):
                sys.exit("request_compact: --then needs a value")
            then = argv[i + 1].strip()
            i += 2
        else:
            rest.append(argv[i])
            i += 1
    return " ".join(rest).strip(), then


def write_request(directory, key, payload):
    os.makedirs(directory, exist_ok=True)
    final = os.path.join(directory, "compact_request_%s.json" % key)
    tmp = final + ".tmp"
    with open(tmp, "w") as f:
        json.dump(payload, f)
    os.replace(tmp, final)
    return final


def main():
    command, then = parse(sys.argv[1:])
    if not command:
        sys.exit('request_compact: usage: request_compact.py "/compact <msg>" [--then TEXT]')
    if command.split()[0] not in ALLOWED:
        sys.exit("request_compact: refused, command must start with one of %s"
                 % ", ".join(ALLOWED))
    if then.startswith("/"):
        sys.exit("request_compact: refused, --then must be a plain message, not a slash command")
    if len(command) > MAX_CHARS:
        sys.exit("request_compact: refused, the line is %d chars (max %d). The compact message is "
                 "1-2 sentences naming the project, the current work and where its notes live; "
                 "details belong in files, not here." % (len(command), MAX_CHARS))
    job = os.path.basename(os.environ.get("CLAUDE_JOB_DIR", "").rstrip("/"))
    pane = "" if job else os.environ.get("TMUX_PANE", "").strip()
    if job:
        key = "j" + "".join(c for c in job if c.isalnum())
    elif pane:
        key = "p" + "".join(c for c in pane if c.isalnum())
    else:
        sys.exit("request_compact: neither $TMUX_PANE (Claude Code inside tmux) nor "
                 "$CLAUDE_JOB_DIR (a background session) is set, so the Stop hook cannot "
                 "reach this session's terminal; give the user this line to paste instead:\n%s"
                 % command)

    cwd = os.getcwd()
    payload = {"key": key, "pane": pane, "job": job, "command": command, "then": then,
               "shell_cwd": cwd, "created": time.time(),
               "created_h": time.strftime("%Y-%m-%d %H:%M:%S")}
    try:
        final = write_request(REQUEST_DIR, key, payload)
    except OSError as e:
        print("request_compact: warning: cannot write %s (%s; Bash sandbox?). Falling back to "
              "the shell cwd; this only works if this shell did not cd within the current "
              "command." % (REQUEST_DIR, e), file=sys.stderr)
        final = write_request(os.path.join(cwd, ".claude", "self-compact"), key, payload)
    print("compact request queued: %s" % final)
    print("End your reply now; the Stop hook delivers it into %s%s." % (
        ("background session %s" % job) if job else ("pane %s" % pane),
        (", then types %r" % then) if then else ", no follow-up"))


if __name__ == "__main__":
    main()
