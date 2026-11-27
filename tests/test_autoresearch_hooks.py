#!/usr/bin/env python3
"""Checks for the autoresearch hooks (context watch, task memory, restore after a compact).

    python3 ~/claude-config/tests/test_autoresearch_hooks.py
"""
import json
import os
import subprocess
import sys
import tempfile
import time

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HK = os.path.join(REPO, "claude", "skills", "autoresearch", "hooks")
WATCH = os.path.join(HK, "context_watch.py")
RESTORE = os.path.join(HK, "post_compact_state.py")
REQUEST = os.path.join(REPO, "claude", "skills", "self-compact", "scripts", "request_compact.py")
results = []


def check(name, cond, extra=""):
    results.append((name, bool(cond)))
    print("%s: %s %s" % ("PASS" if cond else "FAIL", name, extra))


def run(cmd, **kw):
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          universal_newlines=True, **kw)


def as_json(text):
    try:
        return json.loads(text)
    except ValueError:
        return {}


T = os.path.realpath(tempfile.mkdtemp(prefix="autoresearch_test."))
home = os.path.join(T, "home")
os.makedirs(home)
base_env = dict(os.environ, HOME=home)
base_env.pop("TMUX_PANE", None)
base_env.pop("CLAUDE_JOB_DIR", None)
env_p5 = dict(base_env, TMUX_PANE="%5")

research = os.path.join(T, "research")
os.makedirs(os.path.join(research, "agent_notes"))
plain = os.path.join(T, "plain")
os.makedirs(plain)
transcript = os.path.join(T, "transcript.jsonl")


def write_transcript(ctx_tokens):
    lines = [
        json.dumps({"type": "user", "message": {"role": "user", "content": "hi"}}),
        json.dumps({"type": "assistant",
                    "message": {"model": "claude-fable-5",
                                "usage": {"input_tokens": 1000,
                                          "cache_read_input_tokens": ctx_tokens - 2000,
                                          "cache_creation_input_tokens": 1000,
                                          "output_tokens": 5}}}),
        json.dumps({"type": "assistant", "isSidechain": True,
                    "message": {"model": "claude-x",
                                "usage": {"input_tokens": 999999,
                                          "cache_read_input_tokens": 0,
                                          "cache_creation_input_tokens": 0}}}),
    ]
    open(transcript, "w").write("\n".join(lines) + "\n")


def stop_hook(ctx, cwd, active=False, sid="s1", env=base_env):
    write_transcript(ctx)
    payload = {"session_id": sid, "transcript_path": transcript, "cwd": cwd,
               "hook_event_name": "Stop", "stop_hook_active": active}
    return run([sys.executable, WATCH], input=json.dumps(payload), env=env)


# ---- context watch (main agent)
r = stop_hook(100000, research)
check("watch: under limit silent", r.returncode == 0 and r.stdout.strip() == "", r.stdout[:100])
out = as_json(stop_hook(360000, research).stdout)
check("watch: over limit blocks (skips sidechain), points at the self-compact script",
      out.get("decision") == "block" and "360k" in out.get("reason", "")
      and "self-compact/scripts/request_compact.py" in out.get("reason", "")
      and '--then "continue task' in out.get("reason", ""))
check("watch: dampener suppresses re-nudge", stop_hook(365000, research).stdout.strip() == "")
check("watch: re-nudges after +40k growth",
      as_json(stop_hook(505000, research).stdout).get("decision") == "block")
check("watch: stop_hook_active loop guard", stop_hook(420000, research, active=True).stdout.strip() == "")
check("watch: silent + reset after compact", stop_hook(60000, research).stdout.strip() == "")
check("watch: re-arms after reset", as_json(stop_hook(360000, research).stdout).get("decision") == "block")
check("watch: non-research repo silent", stop_hook(500000, plain).stdout.strip() == "")
deep = os.path.join(research, "agent_notes", "tasks", "2026-10-05_09-00_deep", "sub")
os.makedirs(deep)
r = stop_hook(400000, deep, sid="s_deep")
check("watch: hook cwd inside a task folder still nudges; state at the repo root",
      "[context-watch]" in r.stdout
      and any(n.startswith("ctx_") for n in os.listdir(os.path.join(research, ".claude", "autoresearch")))
      and not os.path.exists(os.path.join(deep, ".claude")), r.stdout[:80])

write_transcript(600000)
r = run([sys.executable, WATCH], env=base_env,
        input=json.dumps({"session_id": "s1", "transcript_path": transcript, "cwd": research,
                          "hook_event_name": "PostToolUse", "tool_name": "Bash"}))
out = as_json(r.stdout)
hso = out.get("hookSpecificOutput", {})
check("watch: PostToolUse nudges mid-turn via additionalContext",
      hso.get("hookEventName") == "PostToolUse" and "[context-watch]" in hso.get("additionalContext", "")
      and "decision" not in out, r.stdout[:100])

# ---- a queued self-compact is never blocked by the nudge
r = stop_hook(700000, research, sid="s_q", env=env_p5)
check("watch: over limit in a tmux pane blocks when no compact is queued",
      as_json(r.stdout).get("decision") == "block", r.stdout[:80])
r = run([sys.executable, REQUEST, "/compact keep"], cwd=research, env=env_p5)
reqf = os.path.join(home, ".claude", "self-compact", "compact_request_p5.json")
check("request queued by the self-compact script", r.returncode == 0 and os.path.isfile(reqf), r.stderr[:80])
r = stop_hook(900000, research, sid="s_q2", env=env_p5)
check("watch: Stop with a compact queued is not blocked", r.stdout.strip() == "", r.stdout[:80])
os.replace(reqf, os.path.join(os.path.dirname(reqf), "last_compact_request_p5.json"))
r = stop_hook(900000, research, sid="s_q3", env=env_p5)
check("watch: Stop right after the delivery hook took the request is not blocked",
      r.stdout.strip() == "", r.stdout[:80])
r = stop_hook(900000, research, sid="s_q4", env=dict(base_env, TMUX_PANE="%6"))
check("watch: another session's queued compact does not silence this one",
      as_json(r.stdout).get("decision") == "block", r.stdout[:80])
os.remove(os.path.join(os.path.dirname(reqf), "last_compact_request_p5.json"))


# ---- subagent watch
def sub_hook(ctx_tokens, event="PostToolUse", aid="a1", env=base_env):
    sub_dir = os.path.join(T, "s1", "subagents")
    os.makedirs(sub_dir, exist_ok=True)
    sub = os.path.join(sub_dir, "agent-%s.jsonl" % aid)
    open(sub, "w").write(json.dumps({"type": "assistant", "isSidechain": True, "agentId": aid,
                                     "message": {"model": "claude-fable-5",
                                                 "usage": {"input_tokens": 500,
                                                           "cache_read_input_tokens": ctx_tokens - 1000,
                                                           "cache_creation_input_tokens": 500}}}) + "\n")
    payload = {"session_id": "s1", "transcript_path": transcript, "cwd": research,
               "hook_event_name": event, "tool_name": "Bash", "agent_id": aid,
               "agent_type": "general-purpose", "stop_hook_active": False}
    return run([sys.executable, WATCH], input=json.dumps(payload), env=env)


check("subwatch: under 350k silent", sub_hook(300000).stdout.strip() == "")
ac = as_json(sub_hook(360000).stdout).get("hookSpecificOutput", {}).get("additionalContext", "")
check("subwatch: over 350k -> hand-off nudge via additionalContext",
      "subagent" in ac and "360k" in ac and "return to the main agent" in ac, ac[:100])
check("subwatch: dampened", sub_hook(370000).stdout.strip() == "")
check("subwatch: Stop with agent_id never blocks", sub_hook(900000, event="Stop").stdout.strip() == "")
env_low = dict(base_env, AUTORESEARCH_SUB_CTX_LIMIT="10000")
check("subwatch: limit below the start context -> first call silent (floor)",
      sub_hook(20000, aid="a2", env=env_low).stdout.strip() == "")
r = sub_hook(40000, aid="a2", env=env_low)
check("subwatch: grown past the floor and over the limit -> hand-off nudge",
      "return to the main agent" in r.stdout and "40k" in r.stdout, r.stdout[:80])

# ---- restore after a compact
index = os.path.join(research, "agent_notes", "STATE.md")  # the index when the repo is not under git
open(index, "w").write("# STATE\n- 2026-10-05_08-00_t1 — running — index line X\n")
task_dir = os.path.join(research, "agent_notes", "tasks", "2026-10-05_08-00_t1")
os.makedirs(task_dir)
open(os.path.join(task_dir, "STATE.md"), "w").write("# STATE t1\n## Next steps\n- task step Y\n")
sub = os.path.join(research, "sub")
os.makedirs(sub)
payload = {"cwd": sub, "hook_event_name": "SessionStart", "source": "compact"}
r = run([sys.executable, RESTORE], input=json.dumps(payload), env=env_p5)
check("restore: no touched task -> index + find-your-task text",
      "index line X" in r.stdout and "task step Y" not in r.stdout
      and "no task folder was touched" in r.stdout, r.stdout[:80])
write_transcript(1000)
r = run([sys.executable, WATCH], env=env_p5,
        input=json.dumps({"session_id": "s1", "transcript_path": transcript, "cwd": research,
                          "hook_event_name": "PostToolUse", "tool_name": "Edit",
                          "tool_input": {"file_path": os.path.join(task_dir, "STATE.md")}}))
taskf = os.path.join(home, ".claude", "autoresearch", "task_p5.json")
check("watch: PostToolUse records the touched task folder per session",
      os.path.isfile(taskf) and json.load(open(taskf))["task"] == "2026-10-05_08-00_t1", r.stderr[:80])
r = run([sys.executable, RESTORE], input=json.dumps(payload), env=env_p5)
out = as_json(r.stdout).get("hookSpecificOutput", {})
ac = out.get("additionalContext", "")
check("restore: last touched task's STATE.md + recovery sentence, no index",
      "task step Y" in ac and "last touched" in ac and "index line X" not in ac
      and "autoresearch" in ac and out.get("hookEventName") == "SessionStart", r.stdout[:80])
r = run([sys.executable, RESTORE], input=json.dumps(payload), env=dict(base_env, TMUX_PANE="%6"))
check("restore: another session does not get this session's task",
      "task step Y" not in r.stdout and "index line X" in r.stdout, r.stdout[:80])
open(os.path.join(task_dir, "STATE.md"), "w").write(
    "# STATE t1\n\n## Compact message\nKeep Z.\n\n## Pointers\n- task step Y\n\n## Running jobs\n"
    + "- job line\n" * 700 + "\n## Next steps\n- step N\n\n## Assumptions\n- none\n")
r = run([sys.executable, RESTORE], input=json.dumps(payload),
        env=dict(env_p5, AUTORESEARCH_STATE_MAX="400"))
check("restore: trim keeps the sections that fit, skips 'Compact message', names the oversized one",
      "task step Y" in r.stdout and "Keep Z." not in r.stdout and "job line" not in r.stdout
      and "step N" in r.stdout and "omitted for size, read the file for: Running jobs" in r.stdout,
      r.stdout[-200:])
rec = json.load(open(taskf))
rec["seen"] = time.time() - 13 * 3600
json.dump(rec, open(taskf, "w"))
r = run([sys.executable, RESTORE], input=json.dumps(payload), env=env_p5)
check("restore: a task record older than 12 h is not trusted -> index",
      "index line X" in r.stdout and "job line" not in r.stdout, r.stdout[:80])


def touch(tool_input, cwd=research):
    return run([sys.executable, WATCH], env=env_p5,
               input=json.dumps({"session_id": "s1", "transcript_path": transcript, "cwd": cwd,
                                 "hook_event_name": "PostToolUse", "tool_name": "Bash",
                                 "tool_input": tool_input}))


open(os.path.join(task_dir, "STATE.md"), "w").write("# STATE t1\n## Next steps\n- task step Y\n")
touch({"file_path": os.path.join(task_dir, "STATE.md")})
r = run([sys.executable, RESTORE], input=json.dumps(payload), env=env_p5)
check("restore: the same task touched again after 13 h is fresh again",
      "task step Y" in r.stdout and "index line X" not in r.stdout, r.stdout[:80])
old_dir = os.path.join(research, "agent_notes", "tasks", "2026-10-01_08-00_old")
os.makedirs(old_dir)
open(os.path.join(old_dir, "STATE.md"), "w").write("# STATE old\n- old step Q\n")
touch({"command": "python3 ~/.claude/skills/self-compact/scripts/request_compact.py "
                  "\"/compact keep agent_notes/tasks/2026-10-01_08-00_old/REPORT.md\""})
check("watch: the request_compact.py call does not change the recorded task",
      json.load(open(taskf))["task"] == "2026-10-05_08-00_t1")
touch({"command": "cat agent_notes/tasks/2026-10-05_08-00_t1."})
check("watch: a sentence-ending period is not part of the task id",
      json.load(open(taskf))["task"] == "2026-10-05_08-00_t1", open(taskf).read())
worktree = os.path.join(T, "worktree")
wt_task = os.path.join(worktree, "agent_notes", "tasks", "2026-10-06_08-00_wt")
os.makedirs(wt_task)
open(os.path.join(wt_task, "STATE.md"), "w").write("# STATE wt\n- worktree step W\n")
touch({"file_path": os.path.join(wt_task, "STATE.md")})
r = run([sys.executable, RESTORE], input=json.dumps(payload), env=env_p5)
check("restore: a task folder in another checkout, touched by absolute path, is found",
      "worktree step W" in r.stdout, r.stdout[:120])
touch({"command": "ls agent_notes/tasks/2026-10-09_08-00_ghost"})
r = run([sys.executable, RESTORE], input=json.dumps(payload), env=env_p5)
check("restore: a recorded task without STATE.md -> index, and the text says so",
      "index line X" in r.stdout and "was recorded but has no STATE.md" in r.stdout, r.stdout[:120])
r = run([sys.executable, RESTORE], input=json.dumps({"cwd": plain}), env=env_p5)
check("restore: silent outside research repos", r.stdout.strip() == "")

print()
fails = [n for n, ok in results if not ok]
print("%d/%d passed" % (len(results) - len(fails), len(results)))
if fails:
    print("failed: " + ", ".join(fails))
sys.exit(1 if fails else 0)
