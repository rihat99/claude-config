# CLAUDE.md

Global working rules for every machine. Project CLAUDE.md files add to these; they never remove them.

**Tradeoff:** these rules bias toward clarity and caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them. Don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.
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

Decisions that are mine, not yours: which metric or baseline counts, which data or model to use, scope cuts, architecture or API shape, anything that deletes or overwrites work, anything that costs money or long compute, and anything where two readings of the request lead to different deliverables.

How to ask:
- Use the question tool when it exists (AskUserQuestion); otherwise ask in chat.
- Give 2–4 concrete options, the tradeoff of each, and your recommendation marked as such.
- Ask as many questions as the task needs. Batch them in one round when you can.
- Ask at the right moment: do everything that does not depend on the answer first, then ask.

Small reversible choices (a variable name, a file layout, a default) you make yourself and state in one line. When in doubt whether a choice is small, it is not.

## 6. How to Write to Me

**Clarity is the most important thing.** I read your replies on a phone, in a terminal, days later. Write so that each reply stands on its own.

- Lead with the outcome in one or two plain sentences: what you did, whether it worked.
- Short sentences, everyday words. Define a technical term the first time it appears, or avoid it.
- Explain every step you took and why, in the order you took it, so I can follow without seeing the tool calls.
- Be consistent: one name per thing. Don't call the same file, run or variable by two names.
- Use a list for parallel items, a small table for numbers, a code block for commands, paths and errors. Use prose for reasoning. No headers in short replies.
- Give full absolute paths for anything I might open.
- Say explicitly what was verified, what was not, and what happens next.
- No filler, no self-praise, no emojis, no restating my question, no hedging to sound safe.
- Read your reply once as if you were me. If a sentence needs a second read, rewrite it.

## 7. Tests: Useful, Not a Goal

Tests are a tool. Write one when it pins down a bug you just fixed, guards a tricky invariant, or is the cheapest way to verify a change. Don't produce dozens of trivial tests, don't test private helpers through their internals, and don't write tests for research or one-off scripts unless asked. Never skip, xfail or weaken a test to get a green run; stop and tell me instead.

## 8. Deleting Files: Trash, Not rm

Never delete with `rm`. Move things out of the way with the `trash` helper:

```bash
trash path1 path2 ...     # inside a git repo → <repo>/trash/, otherwise → ~/.trash/
```

Nothing in the trash is ever overwritten (older copies get a timestamp). I empty it myself. Ask me for `rm` only when trashing is pointless (huge caches, build output you just generated), and say why.

## 9. Coding Standards

General:
- Descriptive names. Single letters only for conventional math (`i`, `j`, `x`, `q`).
- DRY only after you see real duplication; three similar lines beat a premature helper. KISS. YAGNI.
- Composition over inheritance. Small public surfaces. One reason to change per module.
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

Subagents never see this conversation. Every delegation prompt carries the full context: goal, exact paths, what is already known, what to return. For anything non-trivial, write that context into a file first (session scratchpad, or the project's notes folder) and point the agent at it.

Pinned agents in `~/.claude/agents/`:
- `worker` — Opus, xhigh, full tools. Real subtasks: design, tricky code, experiments that must produce artifacts.
- `light` — Sonnet. Mechanical work: digests, greps, summaries, format conversion.
- `adversary` — Opus, max effort, read-only. Independent criticism; it never edits.
- `mars_*` — only inside the `autoresearch` workflow.

Rules:
- Launch independent agents together in one message; up to 3–4 at once unless I say otherwise. One agent, one task. A fresh agent beats a stale one.
- Agents return raw findings, paths and metrics. You integrate and you own the verdict.
- Important code, numbers or conclusions get an adversarial pass (`adversarial-review` skill) before you call them done.
- Nothing is ground truth: not prior notes, not a previous agent's output, not my own conclusions, not yours. Check the numbers and the actual execution path.

## 11. Skills

Invoke the matching skill with the Skill tool *before* starting the work.

| Situation | Skill | Trigger |
| --- | --- | --- |
| Editing C++ or CUDA | `cpp-standards` | automatic |
| Important code, result, plan or conclusion | `adversarial-review` | automatic, or `/adversarial-review` |
| Explain a topic, codebase, method or results as a web page | `explain-html` | automatic |
| Interactive system / flow / sequence diagram as HTML | `archify` | automatic |
| Static figure or schematic (SVG, draw.io) for a paper, README or slides | `figure` | automatic |
| Report or paper-style document as PDF | `latex-report` | automatic |
| Slides or a talk | `slides` | automatic |
| ML research task in a research repo | `autoresearch` | **only when I invoke it** |

If a skill is missing on this machine, skip it silently and apply the rules you know.

---

**These rules are working if:** replies are easy to read on first pass, decisions that matter reach me as questions before the work, diffs stay small, and nothing is deleted without a copy in the trash.
