# Compact protocol

Context is an artifact too — a bloated context is entropy. The rule set below
keeps compaction (a) timed at task boundaries, (b) guided by the user's compact
guidelines, (c) near-lossless, because durable state lives in files, not in the
conversation.

## Triggers

- A `[context-watch]` nudge appears (the Stop hook fires when session context
  exceeds the limit, default 350k tokens), OR
- your own judgment at a task boundary: the current task is done and context is
  already fat — don't start the next task on top of it.
- **Never mid-task.** If the nudge arrives mid-task, first bring the task to a
  clean stopping point (or a parked state with everything written down), then
  run the protocol.

## The protocol

1. **Park or finish the task cleanly.** Long-running experiments keep running —
   record how to monitor them (tmux session, PID, log paths, expected finish)
   in the task's `STATE.md`.
2. **Actualize artifacts** — the normal end-of-task cleanup: `REPORT.md`
   finalized (or intermediate notes current), docs updated, junk trashed,
   branch committed.
3. **Update the task's `agent_notes/tasks/<task_id>/STATE.md`** (template
   below — a pointer file, under 6000 bytes) and your line in the index (your
   line only — see SKILL.md §2). Do this last, right before step 4: the task
   folder your last tool call named (the queue command in step 4 does not
   count) is the one whose `STATE.md` comes back after the compact.
4. **Self-issue the compact** (autonomous; the mechanics are the `self-compact`
   skill, `~/.claude/skills/self-compact/SKILL.md`). Compose the 1–2 sentence
   compact message by the rules in that file ("The compact message": high-level,
   names the project, the sub-project, the conclusions and the task state,
   points to files), then queue it:
   ```bash
   python3 ~/.claude/skills/self-compact/scripts/request_compact.py "/compact <the compact message>" --then "continue task <task_id>"
   ```
   Any shell cwd is fine. When your turn ends, the Stop hook types
   `/compact <msg>` into your terminal — the message steers the summarizer, no
   human keystroke — and, once the compact has finished, types the `--then`
   text so you resume. Then **end your reply.**
   - If it refuses (neither inside tmux nor a background session), fall back:
     end your reply asking the user to paste the `/compact <msg>` line.
5. **After compact**, a SessionStart hook puts your task's `STATE.md` (whole
   sections, within 6000 bytes) and one recovery sentence back into context —
   nothing else: the compact summary already carries the narrative, and the
   index is other agents' business. Then the follow-up message arrives. First
   actions: re-invoke the `autoresearch` skill if not loaded, read the files
   `STATE.md` points to (task folder, key docs), resume from "Next steps".

A compact that fires WITHOUT this protocol (built-in auto-compact at the far
end of the window) is restored the same way: the hook knows the task folder you
last touched and puts its `STATE.md` back. Only if no task folder was touched
at all does it inject the index instead, and you find your task there.

## Task STATE.md template (`agent_notes/tasks/<task_id>/STATE.md`)

```markdown
# STATE — <repo> / <task_id> (updated YYYY-MM-DD HH:MM)

## Pointers
- Task status: PLAN.md <status>, REPORT.md <status>
- Key docs: <absolute paths>

## Running jobs
- <tmux session / PID / log path / expected finish>, or "none"

## Next steps
- <1–3 bullets>

## Assumptions pending user confirmation
- <or "none">
```

Pointers and one-liners only — details live in PLAN.md, notes and docs. The
compact message is not stored here: it is composed at compact time (step 4).
After a compact the hook injects these sections whole, in order, within 6000
bytes (`AUTORESEARCH_STATE_MAX`); a section that does not fit is named, not
dumped — keep the file small so nothing is ever left out.

## Hard rules for context hygiene

- Main agent: compact only via this protocol, only at task boundaries.
- Subagents: **never compact, never accumulate.** One subagent = one task =
  one context. Outgrown subagent → findings to its scratch file → dies → fresh
  successor gets the file (see subagent_playbook.md).
- Don't pull huge tool outputs into context when a file path + targeted reads
  will do; don't re-read what's already summarized in notes.
