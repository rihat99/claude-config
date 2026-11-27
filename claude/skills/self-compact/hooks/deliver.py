#!/usr/bin/env python3
"""Stop hook: deliver a compact the agent queued with scripts/request_compact.py.

Looks for this session's compact_request_<key>.json in ~/.claude/self-compact/,
then in <hook cwd>/.claude/self-compact/ (the sandbox fallback). The key is
p<pane> ($TMUX_PANE, e.g. %3 -> p3) in a tmux pane, j<job> ($CLAUDE_JOB_DIR)
for a background session, so several sessions never touch each other's
requests. A found request is renamed to last_compact_request_<key>.json and
handed to scripts/tmux_deliver.py, which detaches and types the command into
the terminal once the TUI is idle. A request older than
SELF_COMPACT_REQUEST_TTL s (default 600) is set aside as
stale_compact_request_<key>.json instead of typed: a compact firing long after
it was asked for would land in the middle of other work. Subagents never
deliver. Log: ~/.claude/self-compact/deliver.log. Fails open on any error.
"""
import json
import os
import subprocess
import sys
import time

ALLOWED = ("/compact", "/clear")
SCRIPTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts")
# Shared with scripts/request_compact.py: per-session request files + deliver.log.
REQUEST_DIR = os.path.join(os.path.expanduser("~"), ".claude", "self-compact")
REQUEST_TTL = int(os.environ.get("SELF_COMPACT_REQUEST_TTL", 600))


def log_line(msg):
    try:
        os.makedirs(REQUEST_DIR, exist_ok=True)
        with open(os.path.join(REQUEST_DIR, "deliver.log"), "a") as f:
            f.write("[%s] %s\n" % (time.strftime("%Y-%m-%d %H:%M:%S"), msg))
    except OSError:
        pass


def find_request(cwd, key):
    name = "compact_request_%s.json" % key
    for d in (REQUEST_DIR, os.path.join(cwd, ".claude", "self-compact")):
        p = os.path.join(d, name)
        if os.path.isfile(p):
            return p
    return None


def deliver_request(cwd, path, key, job, pane):
    target = ("background session %s" % job) if job else pane
    try:
        with open(path) as f:
            req = json.load(f)
    except (OSError, ValueError):
        req = {}
    age = time.time() - float(req.get("created") or 0)
    if not req or age > REQUEST_TTL:
        os.replace(path, os.path.join(os.path.dirname(path),
                                      "stale_compact_request_%s.json" % key))
        log_line("SKIPPED stale request for %s (queued %s, %.0fs old > %ds; file %s)" % (
            target, req.get("created_h", "?"), age, REQUEST_TTL, path))
        return
    os.replace(path, os.path.join(os.path.dirname(path),
                                  "last_compact_request_%s.json" % key))
    command = (req.get("command") or "").strip()
    then = (req.get("then") or "").strip()
    if not command or command.split()[0] not in ALLOWED or then.startswith("/"):
        log_line("REFUSED request for %s (bad command/then; file %s)" % (target, path))
        return
    log_line("request for %s queued %s (shell cwd %s) found at %s; hook cwd %s" % (
        target, req.get("created_h", "?"), req.get("shell_cwd", "?"), path, cwd))
    env = dict(os.environ)
    env["DELIVER_LOG"] = os.path.join(REQUEST_DIR, "deliver.log")
    args = [sys.executable, os.path.join(SCRIPTS, "tmux_deliver.py")]
    args += ["--attach", job] if job else ["--pane", pane]
    if then:
        args += ["--then", then]
    subprocess.run(args + ["--", command], cwd=cwd, env=env, timeout=30,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    data = json.load(sys.stdin)
    if (data.get("hook_event_name") or "Stop") != "Stop" or data.get("agent_id"):
        return
    cwd = data.get("cwd") or os.getcwd()
    job = os.path.basename(os.environ.get("CLAUDE_JOB_DIR", "").rstrip("/"))
    pane = "" if job else os.environ.get("TMUX_PANE", "").strip()
    key = ("j" if job else "p") + "".join(c for c in (job or pane) if c.isalnum())
    if len(key) == 1:
        return
    request = find_request(cwd, key)
    if request:
        deliver_request(cwd, request, key, job, pane)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print("self-compact deliver: %s" % e, file=sys.stderr)
    sys.exit(0)
