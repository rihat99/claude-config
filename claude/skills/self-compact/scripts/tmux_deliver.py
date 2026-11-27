#!/usr/bin/env python3
"""Type one line + Enter into a Claude Code tmux pane once the TUI is idle,
optionally followed by a second line once the TUI is idle again.

Usage: tmux_deliver.py [--pane PANE] [--delay S] [--max-wait S] [--then TEXT] [--now] -- TEXT

Default mode detaches (double fork + setsid) and returns immediately, so a hook
can schedule the keystrokes and exit; --now runs the wait/type loop in the
foreground. PANE defaults to $TMUX_PANE; --attach JOB instead targets a
background session: the worker opens `claude attach JOB` in a scratch window of
the tmux session "self_compact", types there, detaches with Ctrl-Z (the session
keeps running) and closes the window. Log file: $DELIVER_LOG, default
~/.claude/self-compact/deliver.log (one log for all panes; lines name the pane).

Busy detection (capture-pane, polled every 3 s): the TUI is busy while the
screen shows a spinner line such as "Wrangling… (3s · ↓ 24 tokens)" or
"Compacting conversation… (24s)" (Claude Code 2.1) or "esc to interrupt"
(older builds). The text is sent with send-keys -l in 200-char pieces 50 ms
apart, then Enter as a separate key event 0.5 s later (a same-batch Enter is
a newline, not a submit). The pieces matter: a single write of ~900+ chars
is taken for a paste by the Claude Code TUI, and pasted text is submitted as
a plain message, not parsed as a slash command (seen on 2.1.251: the model
answered the "/compact ..." text instead of compacting).
--then TEXT: 2 s after the first line is submitted, type TEXT + Enter. Claude
Code queues input typed during compaction and runs it as the next turn, so
the session resumes without a human keystroke and no spinner detection is
needed for it (observed on 2.1.251). TEXT is a plain message (no leading
"/"). On failure the log gets the reason and the line that was not typed.
Only /compact and /clear lines are delivered as the first line.
"""
import os
import re
import subprocess
import sys
import time

ALLOWED = ("/compact", "/clear")
BUSY = re.compile(r"esc to interrupt|…\s*\(\d+s|Compacting conversation", re.I)
POLL = 3
FOLLOW_DELAY = 2
CHUNK = 200        # chars per send-keys write; larger single writes read as a paste
CHUNK_GAP = 0.05


def log(path, msg):
    try:
        with open(path, "a") as f:
            f.write("[%s] %s\n" % (time.strftime("%Y-%m-%d %H:%M:%S"), msg))
    except OSError:
        pass


ATTACH_SESSION = "self_compact"   # dedicated tmux session for attach windows
ATTACH_SETTLE = 4                 # s for the attached TUI to render


def tmux(*args):
    env = dict(os.environ)
    env.setdefault("TERM", "xterm-256color")   # hooks of a background session have none
    r = subprocess.run(["tmux"] + list(args), stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE, env=env)
    return r.returncode, r.stdout.decode("utf-8", "replace")


def fail(logf, text, why):
    log(logf, "FAILED: %s | %s" % (why, text))
    sys.exit(1)


def screen_busy(pane, logf, text):
    rc, screen = tmux("capture-pane", "-p", "-t", pane)
    if rc != 0:
        fail(logf, text, "pane %s not readable" % pane)
    return bool(BUSY.search(screen))


def wait_idle(pane, max_wait, logf, text):
    waited = 0
    while True:
        if not screen_busy(pane, logf, text):
            return waited
        if waited >= max_wait:
            fail(logf, text, "pane still busy after %ds" % max_wait)
        time.sleep(POLL)
        waited += POLL


def type_line(pane, text, logf):
    for i in range(0, len(text), CHUNK):
        rc, _ = tmux("send-keys", "-t", pane, "-l", "--", text[i:i + CHUNK])
        if rc != 0:
            fail(logf, text, "send-keys text failed")
        time.sleep(CHUNK_GAP)
    time.sleep(0.5)
    rc, _ = tmux("send-keys", "-t", pane, "Enter")
    if rc != 0:
        fail(logf, text, "send-keys Enter failed")


def open_attach(job, logf, text):
    """Show a background session's TUI with `claude attach <job>` in a scratch
    window of a dedicated tmux session (started if needed, over the default
    tmux socket: no $TMUX required) and return that window's pane id."""
    rc, _ = tmux("has-session", "-t", ATTACH_SESSION)
    if rc != 0:
        rc, out = tmux("new-session", "-d", "-s", ATTACH_SESSION, "-x", "200", "-y", "50")
        if rc != 0:
            fail(logf, text, "cannot start tmux session %s: %s" % (ATTACH_SESSION, out.strip()[:120]))
    rc, out = tmux("new-window", "-d", "-P", "-F", "#{pane_id}", "-t", ATTACH_SESSION + ":",
                   "-n", "attach_" + job, "claude attach " + job)
    pane = out.strip().splitlines()[0] if out.strip() else ""
    if rc != 0 or not pane.startswith("%"):
        fail(logf, text, "cannot attach to background session %s: %s" % (job, out.strip()[:120]))
    log(logf, "attached background session %s in %s window %s" % (job, ATTACH_SESSION, pane))
    time.sleep(ATTACH_SETTLE)
    return pane


def close_attach(pane, logf):
    """Detach (Ctrl-Z; the background session keeps running) and drop the window."""
    tmux("send-keys", "-t", pane, "C-z")
    time.sleep(2)
    tmux("kill-window", "-t", pane)
    log(logf, "detached %s" % pane)


def deliver(pane, job, text, then, delay, max_wait, logf):
    time.sleep(delay)
    if job:
        pane = open_attach(job, logf, text)
    try:
        waited = wait_idle(pane, max_wait, logf, text)
        type_line(pane, text, logf)
        log(logf, "typed into %s after %ds idle-wait: %s" % (pane, waited, text))
        if then:
            time.sleep(FOLLOW_DELAY)
            type_line(pane, then, logf)
            log(logf, "typed follow-up into %s (queued behind the compact): %s" % (pane, then))
            time.sleep(FOLLOW_DELAY)
    finally:
        if job:
            close_attach(pane, logf)


def detach(logf):
    """Return True in the fully detached grandchild, False in the parent."""
    if os.fork() > 0:
        return False
    os.setsid()
    if os.fork() > 0:
        os._exit(0)
    fd0 = os.open(os.devnull, os.O_RDONLY)
    fd1 = os.open(logf, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644)
    os.dup2(fd0, 0)
    os.dup2(fd1, 1)
    os.dup2(fd1, 2)
    return True


def clean(s):
    # a trailing ';' would end the tmux command; mid-text ';' is passed through
    return s.replace("\n", " ").strip().rstrip(";")


def main():
    args = sys.argv[1:]
    pane = os.environ.get("TMUX_PANE", "")
    job = ""
    delay, max_wait, now, then = 3.0, 900, False, ""
    while args:
        a = args[0]
        if a == "--pane":
            pane = args[1]; args = args[2:]
        elif a == "--attach":
            job = args[1]; args = args[2:]
        elif a == "--delay":
            delay = float(args[1]); args = args[2:]
        elif a == "--max-wait":
            max_wait = int(args[1]); args = args[2:]
        elif a == "--then":
            then = clean(args[1]); args = args[2:]
        elif a == "--now":
            now = True; args = args[1:]
        elif a == "--":
            args = args[1:]; break
        else:
            break
    text = clean(" ".join(args))
    logf = os.environ.get("DELIVER_LOG") or os.path.join(
        os.path.expanduser("~"), ".claude", "self-compact", "deliver.log")
    os.makedirs(os.path.dirname(logf), exist_ok=True)

    if not text:
        sys.exit("tmux_deliver: no text given")
    if text.split()[0] not in ALLOWED:
        sys.exit("tmux_deliver: refused, text must start with one of %s" % ", ".join(ALLOWED))
    if then.startswith("/"):
        sys.exit("tmux_deliver: refused, --then must be a plain message, not a slash command")
    if not pane and not job:
        fail(logf, text, "no target: neither --pane/$TMUX_PANE nor --attach <job>")
    target = ("background session %s (via claude attach)" % job) if job else ("pane %s" % pane)

    if now:
        deliver(pane, job, text, then, delay, max_wait, logf)
        return
    if detach(logf):
        deliver(pane, job, text, then, delay, max_wait, logf)
        os._exit(0)
    print("scheduled into %s after >=%.0fs idle (log: %s)" % (target, delay, logf))


if __name__ == "__main__":
    main()
