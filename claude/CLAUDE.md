# CLAUDE.md

Global working rules for every machine. Project CLAUDE.md files add project specifics on top; a project file wins only where it explicitly overrides one of these rules.

**Tradeoff:** these rules bias toward clarity and caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them. Don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, name what's confusing and ask (§5 says how and when).
- Read the existing code and notes first. Reuse what already works before writing new code.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it. Don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Turn tasks into checks you can run:
- "Fix the bug" → reproduce it first, then make the reproduction pass.
- "Add validation" → list the invalid inputs, show each one is rejected.
- "Refactor X" → the same checks pass before and after.

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification. Report what you verified and what you did not. Never claim success you have not seen.

## 5. Ask Before Deciding

**Never silently decide something that changes the result.**

Decisions that are mine, not yours: which metric or baseline counts, which data or model to use, scope cuts, architecture or API shape, anything that deletes or overwrites work, anything that costs money or long compute (more than about an hour of GPU time), and anything where two readings of the request lead to different deliverables.

How to ask:
- Use the question tool when it exists (AskUserQuestion); otherwise ask in chat.
- Give 2–4 concrete options, the tradeoff of each, and your recommendation marked as such.
- Ask as many questions as the task needs. Batch them in one round when you can.
- Ask at the right moment: do everything that does not depend on the answer first, then ask.

Small reversible choices (a variable name, a file layout, a default) you make yourself and state in one line. When in doubt whether a choice is small, it is not.

If I said I am away, or a question cannot reach me: take the recommended option when it is reversible, record it under **Assumptions** in your reply or notes, and continue. Stop and wait only before something irreversible or costly. A skill I invoked may set its own rule for this (autoresearch does); follow it there.

## 6. How to Write to Me

**Clarity is the most important thing.** I read your replies on a phone, in a terminal, days later. Write so that each reply stands on its own.

- Lead with the outcome in one or two plain sentences: what you did, whether it worked.
- Short sentences, everyday words. Define a technical term the first time it appears, or avoid it.
- Explain every step that mattered and why, in order, one line each, so I can follow without seeing the tool calls.
- Be consistent: one name per thing. Don't call the same file, run or variable by two names.
- Use a list for parallel items, a small table for numbers, a code block for commands, paths and errors. Use prose for reasoning. No headers in short replies.
- Give full absolute paths for anything I might open.
- Say explicitly what was verified, what was not, and what happens next.
- No filler, no self-praise, no emojis in replies, no restating my question, no hedging to sound safe.
- Read your reply once as if you were me. If a sentence needs a second read, rewrite it.

## 7. Tests: Useful, Not a Goal

Tests are a tool. Write one when it pins down a bug you just fixed, guards a tricky invariant, or is the cheapest way to verify a change. Don't produce dozens of trivial tests, don't test private helpers through their internals, and don't write tests for research or one-off scripts unless asked. Never skip, xfail or weaken a test to get a green run; stop and tell me instead.

## 8. Deleting Files: Trash, Not rm

Never delete with `rm`. Move things out of the way with the `trash` helper:

```bash
trash path1 path2 ...     # inside a git repo → <repo>/trash/, otherwise → ~/.trash/
```

Nothing in the trash is ever overwritten (older copies get a timestamp). I empty it myself (on the Mac `~/.trash` is the Finder Trash, which Finder may empty after 30 days; you cannot list it there, and that is fine). Ask me for `rm` only when trashing is pointless (caches or build output you just generated, more than a few GB, or a path on another filesystem that `trash` refuses), and say why.

## 9. Coding Standards

General:
- Descriptive names. Single letters only for conventional math (`i`, `j`, `x`, `q`).
- Share code only after you see real duplication; three similar lines beat a premature helper. Keep it simple; build nothing for a future need.
- Composition over inheritance. Small public surfaces. Each module does one job.
- In an existing file, the file's own style wins over the rules below.
- No silent fallbacks or broad `try/except` that hide real errors. Validate at user-facing boundaries, trust internal callers.
- Comments explain *why*, never *what*. No progress notes, logs or summaries inside code; notes go in the project's notes folder or the reply.
- No new dependencies without checking the project's manifest and asking.
- Profile before optimizing.

Python:
- Type hints on every public signature. Docstrings on public functions and classes; the first line sits on the same line as the opening `"""`. Document tensor/array shapes, e.g. `q: (B, nq)`.
- Follow the project's formatter and linter config (`ruff`, `black`, `flake8`); never reformat a file to a different style.
- Run Python through the project's environment (`uv run`, the project venv, or the conda env the project names). Never install into system Python.
- Use the project's logging helper if one exists instead of `print`.

Files and modules:
- Match the repository's existing naming convention first.
- Internal implementation families: `category_specific.py` (`optimizer_mppi.py`, `primitive_sphere.py`), class in natural order (`MppiOptimizer`).
- Public API modules: plain descriptive names a library user expects (`robot.py`, `inverse_kinematics.py`).
- One main class per file.

C++ / CUDA: invoke the `cpp-standards` skill before editing `.cpp`, `.h`, `.cu`, `.cuh`.

## 10. Delegation and Verification

**If you are a subagent** (your task arrived as a brief from another agent): do that task only. Do not spawn agents or run `adversarial-review` unless the brief says so, put open questions in your final message instead of asking, and skip §6; your reader is the agent that spawned you.

Subagents other than forks never see this conversation. Every delegation prompt carries the full context: goal, exact paths, what is already known, what to return. For anything non-trivial, write that context into a file first (the session scratchpad if there is one, else the project's notes folder) and point the agent at it.

Models come in three tiers, `fable`, `opus` and `sonnet`. The exact version and effort of each tier live in one file, `~/claude-config/claude/models.json`; never hard-code a model id anywhere else. Subagents run on the `opus` tier by default, whatever model this session runs on (forks and the built-in Plan agent follow the session model). Use `sonnet` only for trivial mechanical work. Prefer `worker` to the built-in general-purpose agent: `worker` pins its effort, general-purpose inherits the session's. Never pass `model:` when spawning an agent unless I ask.

Pinned agents in `~/.claude/agents/`:
- `worker` — opus tier, full tools. Real subtasks: design, tricky code, experiments that must produce artifacts.
- `light` — sonnet tier. Mechanical work: digests, greps, summaries, format conversion.
- `adversary` — opus tier at max effort, read-only. Independent criticism; it never edits.
- `mars_*` — only inside the `autoresearch` workflow; all on the opus tier except `mars_light` (sonnet).

Rules:
- Launch independent agents together in one message; up to 3–4 at once unless I say otherwise. One agent, one task. A fresh agent beats a stale one.
- Agents return raw findings, paths and metrics. You integrate and you own the verdict.
- Important code, numbers or conclusions get an adversarial pass (`adversarial-review` skill, main session only) before you call them done.
- Inside an `autoresearch` task its playbook replaces these rules: `mars_*` agents only, `mars_aux` for adversarial checks, up to 6 at once.
- Nothing is ground truth: not prior notes, not a previous agent's output, not my own conclusions, not yours. Check the numbers and the actual execution path.

## 11. Skills

Invoke the matching skill with the Skill tool *before* starting the work:

- C++ or CUDA files → `cpp-standards`.
- Important code, result, plan or conclusion → `adversarial-review` (main session only, or when I type `/adversarial-review`).
- A static diagram, schematic or figure for a paper, README, poster or slides → `figure` (SVG). draw.io only when I say draw.io.
- An interactive HTML map of a system, flow or sequence → `archify`, only when I ask for one.
- A web page or explainer I can open in a browser → `explain-html`, only when I ask for one; otherwise answer in chat.
- A PDF report, paper draft or technical note → `latex-report`.
- Slides, a deck or a talk → `slides`.
- Charts and data plots → matplotlib, no skill.
- `autoresearch` → only when I invoke it myself.

If a skill is missing on this machine, say so in one line and apply the rules you know.

---

**These rules are working if:** replies are easy to read on first pass, decisions that matter reach me as questions before the work, diffs stay small, and nothing is deleted without a copy in the trash.
