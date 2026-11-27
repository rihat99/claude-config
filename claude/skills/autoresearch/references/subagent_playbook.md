# Subagent & Aux-agent Playbook

How deep tasks get run. The main agent is the **orchestrator and integrator**:
subagents produce raw material; only the main agent writes canonical artifacts.

## Model & effort tiers — enforced by agent definitions

Spawn subagents **only** via these `subagent_type`s. `install.sh` puts them in
`~/.claude/agents/mars_*.md`, where model, effort and tools are pinned — never
pass `model:` in the Agent call (it would override the pin).

- `mars_light` — sonnet, xhigh: no-brainer / mechanical work: file digests,
  greps, summaries, boilerplate.
- `mars_top` — the session model (fable or opus, the user's choice), xhigh:
  cornerstone work: real thinking, design, tricky code/math, anything that
  must execute and produce artifacts, final conclusions. **Default when
  unsure** — most real subtasks deserve it. **At most one at a time.**
- `mars_top_opus` — Opus 5.5, xhigh, full tools: the same job, for every
  further concurrent top-tier worker (any number, see Parallelism).
- `mars_aux` — Opus 5.5 (pre-frontier), xhigh, Write/Edit disallowed: the aux
  agent (next section).

## Aux model (config)

```
aux_model: opus5.5-xhigh
```

The **aux agent** does what codex used to: read-only discovery and tracing,
offload, and adversarial cross-checks. Values:

- `opus5.5-xhigh` (default) — `mars_aux`. To change its model or effort edit
  `~/.claude/agents/mars_aux.md` (package: `agents/mars_aux.md`). Codex is
  **off**: never call `codex`.
- `gpt-6-astra` — codex. Only when the user switches to it; see
  "Codex mode" below.

## Parallelism

- **Fable is scarce: never more than one `mars_top` at a time**, even when the
  session model is fable. Every further concurrent top-tier worker is a
  `mars_top_opus`; `mars_aux` and `mars_light` are never fable.
- **Opus/Sonnet agents (`mars_top_opus`, `mars_aux`, `mars_light`): run as many
  in parallel as the work splits into, up to 6 at once.** Beyond 6, ask the
  user. Send concurrent agents in ONE message so they run together.
- Independent work → parallelize. Dependent work → chain and pass results
  forward.

## Delegation

The main agent orchestrates and integrates; it does not run the work. Builds, test suites, benchmarks, training or evaluation runs, data conversion, GPU and environment checks, log digging, run→inspect→fix loops, multi-file reading, and edits across more than one or two files all go to subagents with a brief. The main agent keeps for itself: reading notes and briefs, the task's canonical files (`PLAN.md`, `STATE.md`, `REPORT.md`), spawning agents and reading their reports, reviewing what they return, and trivial one-liners (`ls`, `git status`, a small `cat`, a path check). Before a third Bash call in a row, or any command expected to run longer than a minute, stop and write a brief instead.

- Shell work: one `mars_top` / `mars_top_opus` brief per unit of work. The agent runs it, iterates on failures, and returns ≤30 lines plus absolute paths to logs and artifacts. For a long job it stays alive to poll and report; the main agent does not sleep-and-check.
- Long jobs: start with `nohup <cmd> > <log> 2>&1 & echo $!`, write the PID into `STATE.md` next to the log path, and stop the job with `kill <that number>` typed as a literal (`kill 12345`). `kill` with a literal PID and `pkill` run without a prompt; `kill $(cat pidfile)` and `kill $PID` do not match the allow rule (rules cannot check commands with variables), so they wait for auto mode's check and can be refused. Never `pkill -f <pattern>`: it also matches the shell running the command and kills you; use `pkill -x <name>` or the PID. Before killing, confirm the process is yours: `tr '\0' '\n' < /proc/<pid>/environ | grep CLAUDE_CODE_SESSION_ID` must show this session's id.
- Code changes: assign the files to a `mars_top*` agent in its brief (the artifact contract's "ownership of specific files"). The main agent reviews the diff and integrates; it does not retype the edits.
- Reading and searching: `mars_aux` for tracing and investigation, `mars_light` for mechanical digests and greps.
- Reviews: `mars_aux` with a clean context, as the Verify section says.

Why: the main agent runs on the most expensive model with the largest context, and every command output it reads stays in that context until the next compact, re-read on every later call. Subagents are cheaper, start fresh, and die when done.

## Aux agent = full agent (discovery + offload + adversary)

- Use it like any Claude agent for general read-only work: code tracing,
  multi-file investigation, discovery, summaries, offload.
- **Its real edge: adversarial criticism / independent cross-check** of
  important code or conclusions — always spawn it with a clean context so it
  isn't biased toward defending the main agent's work.
- It cannot edit files (Write/Edit disallowed) — it returns its findings in
  the final message and the main agent integrates them.
- It doesn't see the conversation — give it **full self-contained context**
  in the prompt (reuse the handoff file below).

### Codex mode (only when `aux_model: gpt-6-astra`)

- Codex does not count against the Claude cap; run as many codex jobs as
  useful in the background. It is read-only: it cannot write files, edit
  code, render images, or iterate run→inspect.
- `gpt-6-astra`, `xhigh`, `service_tier=fast`, read-only; run in the
  background and read the output file when it finishes:
  ```bash
  codex exec -m gpt-6-astra -c 'model_reasoning_effort="xhigh"' -c 'service_tier="fast"' \
    --skip-git-repo-check -C <repo> -s read-only "$(cat /tmp/<name>.txt)" </dev/null
  ```
  **`</dev/null` is mandatory when running in the background**: with a non-TTY
  open stdin, codex sits in "Reading additional input from stdin..." forever
  and never starts (no rollout file appears in `~/.codex/sessions` — that's the
  tell).
- Write the prompt to a meaningful `/tmp/<name>.txt`, capture output to
  `/tmp/<name>.out`, then read it. (Run scripts live in `/tmp` as
  `run_codex_<name>.sh`.)

## Context handoff = "branch version of you"

- Give every subagent **all** context it needs in the first prompt — they don't
  see this conversation.
- For non-trivial spawns, first write a handoff file capturing what the main
  agent already knows, then hand the subagent that file path. Canonical home:
  `agent_notes/tasks/<task_id>/subagents/context_<topic>.md` (part of the task
  record, survives reboots). `/tmp/<topic>_context.md` is acceptable for
  throwaway spawns. Reuse/extend one file across related spawns — don't fork
  five diverging context files (entropy).

## Subagent artifact contract (entropy control)

- Every brief states: the goal, the context file, the **allowed write paths**,
  and the expected return format ("≤30-line summary + file paths").
- Subagents write ONLY inside their assigned scratch area
  (`agent_notes/tasks/<task_id>/subagents/` or `/tmp`) — never canonical docs,
  never code paths, unless the brief explicitly assigns ownership of specific
  files. Parallel agents get **disjoint** file sets.
- Subagents return raw material; the **main agent** integrates it into
  canonical artifacts (code, REPORT.md, docs) and trashes the scratch during
  task cleanup.

## Fresh-context hard rule

- One subagent = one task. When its task is done, it dies. Do not keep a
  long-lived subagent conversation going through rounds of drift — spawn a
  fresh one with an updated context file instead.
- If a subagent's job outgrows its context, it writes findings to its scratch
  file and reports; the main agent spawns a successor pointed at that file.
  The context-watch hook enforces this: above `AUTORESEARCH_SUB_CTX_LIMIT`
  (default 350k) the subagent gets a `[context-watch]` hand-off nudge after its
  next tool call — but never before it has grown 5k past its start context
  (~20k), so a successor always makes progress first. Every handoff file must
  therefore name the scratch/state path the subagent writes to.
- The main agent's own context is governed by the compact protocol
  (`compact_protocol.md`); subagents never compact.

## Verify important things adversarially

- For any important code written OR conclusion reached: spawn subagent(s) to
  **verify / criticize / hunt bugs & corner cases**. A few rounds of
  back-and-forth arguing is good, not wasteful.
- Use a **clean-context** agent (the aux agent) so it isn't biased toward defending
  the main agent's own work.

## Skepticism — nothing is ground truth

- Be critical of conclusions in `agent_notes/` — they are prior agents' output;
  they can be wrong or over-stated.
- Be critical of the user's own conclusions too — sanity-check the
  reasoning/numbers rather than treating them as GT.
- Prefer logging **raw metrics + trajectory**; the user owns the final verdict.

## House rules that interact with the above

- Never delete — use `trash <paths...>` for cleanup moves.
- Never `pip install`; ask before destructive/irreversible ops.
- Write multi-line scripts to a meaningful `/tmp/<name>.{py,sh}` and run them —
  no `python -c` one-liners, no heredocs.
- Verify runtime values from the execution path, not defaults/names, before
  relying on them.
