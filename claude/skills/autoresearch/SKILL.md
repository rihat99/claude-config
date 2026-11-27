---
name: autoresearch
description: >-
  ML research workflow for the user's research repos. Use for ANY research task:
  running or analyzing experiments, ablations, training runs, implementing or
  improving methods, GPU jobs, or writing research reports. Enforces the task
  intake interview, agent_notes artifact discipline (PLAN/REPORT, entropy
  control), the subagent playbook, GPU acquisition, working hours, and the
  compact protocol.
---

# Autoresearch workflow

Operating principle: **entropy must not grow.** Every artifact — code, data,
notes, experiments — has exactly one canonical home. After every task, artifacts
are either actualized or trashed. Never leave parallel half-truths lying around.

Helper scripts: `~/.claude/skills/autoresearch/scripts/gpu_free.py`, the
`trash` command, and `~/.claude/skills/self-compact/scripts/request_compact.py`.

## 0. Task lifecycle

intake interview → `PLAN.md` + task `STATE.md` + index line → execute
(checkpoint the task `STATE.md` at milestones) → `REPORT.md` → cleanup + commit
→ drop the index line → (compact protocol, only at a task boundary).

## 1. Task intake — anti-lazy interview (mandatory)

Follow `references/intake_checklist.md`. Investigate the repo/notes yourself
first; then interview the user (AskUserQuestion) about every unresolved ⚠ item —
metrics, baseline, deliverable, data paths. **Do not start a task while those
are guesses.** The interview happens once, at task start, while the user is
present. Mid-task questions obey working hours (§6).

## 2. Artifacts & entropy control

- `agent_notes/tasks/<task_id>/` — one flat folder per task, date-labeled:
  `<task_id>` = `YYYY-MM-DD_HH-MM_<task_name>` (task start, Asia/Dubai:
  `TZ=Asia/Dubai date +%Y-%m-%d_%H-%M`), e.g.
  `agent_notes/tasks/2026-10-05_08-00_lr_sweep/`. Starts with `PLAN.md` and
  `STATE.md`, ends with `REPORT.md`; intermediate notes as needed; subagent
  scratch in `subagents/` inside it. Older flat `tasks/<name>/` folders stay
  where they are.
- `agent_notes/tasks/<task_id>/STATE.md` — the task's rolling checkpoint, a
  **pointer file under 6000 bytes**: task status, key docs, running jobs, next
  steps, pending assumptions (template in `references/compact_protocol.md`).
  Update it at milestones (jobs launched, results in) and before any compact;
  it is what comes back into context after a compact.
- `agent_notes/docs/` — durable agent documentation. Update in place; never
  create a second doc about the same thing.
- The task **index** — `$(git rev-parse --git-common-dir)/autoresearch/STATE.md`
  (= `.git/autoresearch/STATE.md` of the main checkout: one file shared by the
  main checkout and all its worktrees, never under git). Read by many parallel
  agents, so ultra-brief: one line per active task, ~15 lines max, no details.
  ```
  # STATE — <repo>
  - <task_id> — <planning|running|blocked|parked> — <what, ≤10 words>
  ```
  Edit **only your own task's line** (re-read the file right before editing;
  never rewrite or reorder other lines). Add it at task start; drop it once
  the task is reported and committed. A tracked old-style `agent_notes/STATE.md`
  → move its content into the matching task's `STATE.md`, then trash it (a
  tracked index diverges per branch).
- Git: `agent_notes/` notes **are committed** — markdown, plus small text
  files the notes rely on (scripts, metric JSONs, short logs). Temporary
  visualizations go to `vis/` and other generated artifacts (renders, videos,
  dumps, checkpoints) to `artifacts/` inside the task folder; both are
  gitignored (`agent_notes/**/vis/`, `agent_notes/**/artifacts/`) but stay on
  disk, so REPORT.md can still point at them by absolute path.
- Code: clean, minimal comments. Comments never turn into notes or logs — notes
  belong in `agent_notes/`. Prefer reusing code that is known to work over
  writing new code. Smallest diff that does the job.
- Tests: **do not write tests by default** — this is ML research, they are
  clutter. Exception: genuinely bug-prone primitives (CUDA kernels, tricky data
  transforms with many edge cases).
- Data: keep it where data lives on this machine (usually
  `/data*/<username>/...`). If unsure — ask the user. Never into the repo.
- Anything shown to the user (figures, tables, reports): give **full absolute
  paths**, never relative.

## 3. Experiments

- Naming consistent with the repo's existing scheme. Almost every experiment
  builds on a baseline → the name must say *what changed* relative to it.
- Report exactly the metrics agreed at intake — those are the results; nothing
  substituted, nothing omitted.
- `REPORT.md` is self-contained: what the baseline is, what each variant changes
  vs. baseline, the metric table, absolute paths to figures. The user may read
  it days later with zero context in their head.

## 4. Git

- Each task on its own branch created for it (`task/<task_name>` unless the repo has
  its own scheme). Commit the finished work to that branch.
- **Never merge.** The user reviews and decides whether and how to merge.

## 5. Subagents

Follow `references/subagent_playbook.md`: spawn only the `mars_*` agents
(`mars_light` / `mars_top` / `mars_top_opus` / `mars_aux` in
`~/.claude/agents/` — model and effort are pinned there; never pass `model:`
yourself; at most one `mars_top` at a time, fable is scarce; up to 6 Opus/Sonnet
agents in parallel), the parallelism rules,
the aux agent (`aux_model`, default Opus 5.5 xhigh = `mars_aux`; codex is
off), self-contained context handoff files, adversarial verification of
important results, and the fresh-context hard rule (one subagent = one task;
never keep refining a stale subagent).

Delegation (details: `references/subagent_playbook.md`, Delegation). The main agent orchestrates and integrates; it does not run the work. Builds, test suites, benchmarks, training or evaluation runs, data conversion, GPU and environment checks, log digging, run→inspect→fix loops, multi-file reading, and edits across more than one or two files all go to subagents with a brief. The main agent keeps for itself: reading notes and briefs, the task's canonical files (`PLAN.md`, `STATE.md`, `REPORT.md`), spawning agents and reading their reports, reviewing what they return, and trivial one-liners (`ls`, `git status`, a small `cat`, a path check). Before a third Bash call in a row, or any command expected to run longer than a minute, stop and write a brief instead.

## 6. Talking to the user, working hours

- There is no notification channel: the user reads your replies and the task
  files when they come back. When a task is complete, preliminary results are
  in (`REPORT.md` ready), a long run finished or crashed, or you need an
  answer, say it in the first line of the reply (done, results, crash,
  question) with the absolute path to the details, and record it in the task
  `STATE.md`.
- Working hours: **10:00–22:00 Asia/Dubai** (user may adjust per situation).
  Check with `TZ=Asia/Dubai date +%H`.
  - Inside working hours: you may ask and wait for the answer.
  - Outside: **never block on the user.** Make the conservative choice, record
    it in the task notes under `## Assumptions (made off-hours)`, and keep
    working.

## 7. GPUs

- Before any GPU job:
  `python3 ~/.claude/skills/autoresearch/scripts/gpu_free.py --top <K> --need-gb <N>`
  with the number of GPUs and the VRAM the job needs (15 s sampling window;
  avg util + avg VRAM + process owners and ages). With K GPUs `FREE` it
  returns at once; otherwise it watches shared candidates for 60 s before
  trusting them.
- Take `FREE` and `PRACTICALLY_FREE` GPUs. `PRACTICALLY_FREE` = someone's
  long-running processes are there but use little of the GPU (the status shows
  their avg util) and `--need-gb` VRAM is left — fine to share. Never take
  `PRACTICALLY_FREE_NO_VRAM` or `BUSY`. Respect GPU constraints given at intake.
- Sharing tolerance (`--share-util`): **≤25% avg util is enough for most
  tasks** (the default). Light or latency-tolerant jobs (eval, inference,
  debugging, small runs) may go up to `--share-util 50`. Speed/throughput
  measurements: `FREE` only — a shared GPU skews timings.
- Set `CUDA_VISIBLE_DEVICES` explicitly for every launch; state it in notes.

## 8. Cleanup (end of every task)

- Actualize: finalize `REPORT.md`, update touched docs in place, mark the
  task `STATE.md` done, drop the task's line from the index (§2).
- Stale intermediates, dead code, scratch files → `trash <paths...>`
  (moves into repo `trash/`; the user empties it). Never delete — always trash.
- Ensure `.gitignore` covers `trash/`, `.claude/`, `agent_notes/**/vis/` and
  `agent_notes/**/artifacts/`. Commit the task branch (notes included).

## 9. Compact protocol

Follow `references/compact_protocol.md`. Triggers: a `[context-watch]` nudge
(context above the limit) or your own judgment at a task boundary. **Never
compact mid-task** — reach a clean stopping point first. The agent issues the
compact **itself**, autonomously, with the `self-compact` skill's script: stage
everything (the task `STATE.md` + the compact message), then queue it with
`python3 ~/.claude/skills/self-compact/scripts/request_compact.py "/compact <msg>"
--then "continue task <task_id>"` and end the reply; the Stop hook types it
into your terminal when your turn ends. No human keystroke; falls back to
asking the user only if `request_compact.py` refuses (neither tmux nor a
background session).

## 10. Skepticism

Nothing is ground truth: not conclusions in `agent_notes/` (prior agents wrote
them), not the user's own conclusions. Sanity-check reasoning and numbers from
raw metrics and actual execution paths, not from names, defaults, or memory.
