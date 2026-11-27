# 10. Agents

The agent file is `CLAUDE.md` at the root: a short map of what the code cannot tell, with the tier commands at the
top (6.9). Procedures live in skills and area traps in nested agent files, and a rule that must hold is a check, not
emphasis (6.1). Plans live in the notes folder (9.7), and every hand-off stands alone with evidence a reader can
rerun. Code that is easy for an agent is code that is easy for a person: literal names, small output, one command
per question.

## Principles

### 10.1 Keep one agent file, `CLAUDE.md`, at the root, and point every other agent at it [Law 2]
**Why.** Two instruction files drift, and one of them is always the stale one. Claude Code reads `CLAUDE.md`, other
agents read `AGENTS.md`, and a one-line `AGENTS.md` that names `CLAUDE.md` reaches them without a second source. It
is a file, not a symlink (9.3). Some agents read only the files from the root down to their working directory, once,
at start, while Claude Code also loads a nested `CLAUDE.md` when it reads a file in that folder. So a rule every
agent must see lives in the root file or in a doc the root file names.

**Example.** The whole of `AGENTS.md`:
```markdown
Read `CLAUDE.md` in this directory: it is this repository's agent file.
```

**Check.** A contract test fails when `AGENTS.md` is more than one line or names another file, and when any other
instruction file exists (`.cursorrules`, `.cursor/rules/`, `.github/copilot-instructions.md`).

### 10.2 Write in the agent file only what the code cannot tell [Law 10]
**Why.** The agent file loads into every session, so each line costs context in every task. An agent reads the
repository itself: an overview of the layout or a list of modules does not shorten its search, and every restated
fact drifts. What the code cannot tell: the tier commands with their times (6.9), places where the code misleads,
decisions taken outside the code, invariants that are absences with their enforcers (7.7), non-goals and the
rejected list (8.3), the gates that must not be weakened, and where the data lives. Machine and GPU assignments
change per task and belong in the task brief. Keep the root file under 200 lines and a nested file under 60.

**Example.** `BetterHuman/CLAUDE.md` states its gates with numbers, which no file listing shows (abridged):
```markdown
## Gates that must not be weakened

- SMPL-X parity 1e-6 m (float32 and float64, expression streamed); current worst 5.1e-7 m.
- `stream_joints=False` error stays in (1e-5, 2e-3) m.
Never skip, xfail or loosen a test to get green; report the number instead.
```
`BetterRobot/src/better_robot/lie/CLAUDE.md` lists every function of every module, which the modules show anyway.

**Check.** A contract test bounds the root agent file at 200 lines and nested files at 60, and fails on a word in
capitals used for emphasis (`NEVER`, `IMPORTANT`), because a rule that must hold is a check (6.1). Review question
for each line: would an agent that reads the code learn this anyway?

### 10.3 Put procedures in skills and area traps in nested agent files, and commit the shared agent configuration [Law 2]
**Why.** A multi-step procedure (add a joint type, add a body family, regenerate goldens, cut a release) matters in a
few sessions and costs context in all of them; a skill loads only when the task needs it. A trap belongs next to the
code it is about: a nested `CLAUDE.md` loads when an agent reads a file in that folder, and it holds that folder's
traps and invariants, with correct and wrong code side by side. Design reasoning and measured timings belong in the
module's design note (7.6). Skills, path-scoped rules and settings that every contributor needs are part of the
repository; personal session files are not.

**Example.** A trap in `BetterRobot/src/better_robot/kinematics/CLAUDE.md` (paraphrased):
```python
# Right: a LOCAL_WORLD_ALIGNED Jacobian becomes body-frame by rotation only.
R_ee = so3.to_matrix(T_ee[..., 3:])
J_local = torch.cat([R_ee.mT @ J_world[..., :3, :], R_ee.mT @ J_world[..., 3:, :]], dim=-2)
# Wrong: the full adjoint adds a spurious cross term.
# J_local = se3.adjoint_inv(T_ee) @ J_world
```
The same file also carries a section of launch counts and timings, which is a design note in an agent file.

**Check.** `.gitignore` admits `.claude/settings.json`, `.claude/rules/` and `.claude/skills/` and ignores the rest
of `.claude/`, and `git ls-files .claude` lists every shared skill and rule the agent file mentions. Review question
for each section of a nested agent file: is this a trap an agent would fall into, or a design note?

### 10.4 Spend the agent's context on the code: keep generated trees out of its reads and every output short [Law 10]
**Why.** Agents find code by search and read it through a fixed window, so every line of noise displaces a line of
code. Explicit, searchable code and short `repr`s are set in 4.2 and 4.9; this rule covers what surrounds the code.
Generated, vendored and stale trees answer searches with text nobody maintains, so ignore rules and read-deny rules
keep them out. Commands in the agent file run quietly and print failures in full, because a log of thousands of
passing lines buries the one line that matters.

**Example.** Shared settings in `.claude/settings.json`:
```json
{"permissions": {"deny": ["Read(./docs/_build/**)", "Read(./site/**)"]}}
```

**Check.** Every ignored tree of text on disk (`_build/`, `site/`) has a read-deny rule. Every test command in the
agent file runs with `-q`.

### 10.5 Make every hand-off stand alone, with evidence a reader can rerun [Law 9]
**Why.** The next reader has nothing else open: a helper agent sees only its brief, and the owner reads a report days
later on a phone. The global rules require full context in a delegation prompt, and a reply that says what was
verified and what was not; this rule applies both to every artifact an agent leaves behind: briefs, plans,
`STATE.md`, reports and commit messages. Each one states its goal, gives paths that resolve for its reader (absolute
in a reply, as the global rules ask, and in a note; relative to the repository root in a tracked file, 12.4), and
backs each claim with the exact command, the output line that proves it, and what was not run, skipped tests
included.

**Example.** A hand-off that accounts for every skip:
```text
Goal:     check that BetterRobot's contract tests are green at 20862fe
Verified: uv run pytest tests/contract -q -rs  ->  729 passed, 8 skipped in 2.05s
Skipped:  6 mutable by design (test_frozen.py exception list); 1 known violation (viewer.MeshSpec is not frozen);
          1 empty parameter set in test_docstrings.py, so that test checks nothing
Not run:  the CUDA tests (no GPU assigned to this task)
```

**Check.** Review questions: could a reader with only this file act on it? Does every "passes", "faster" or "fixed"
carry its command and its output line, and is every skip accounted for?

## Application profile

Relaxed:
- Skills for procedures are optional.

Not relaxed:
- One agent file under 200 lines, commands first, absences with enforcers, no history, plans in the notes folder,
  evidence with every claim.
- An application's agent file also names the data root variable, points at the stage table (12.6), and says how a
  run resumes; it does not copy the stage table.

## Checklist
- [ ] Is `CLAUDE.md` the only agent file, with at most a one-line `AGENTS.md` that points at it?
- [ ] Does every line of the agent file say something the code cannot, within 200 lines (60 for a nested file),
  with no capitals for emphasis?
- [ ] Are procedures in skills, traps in nested agent files, and shared agent configuration tracked?
- [ ] Are generated trees kept out of agent reads, and does every listed command run quietly?
- [ ] Does every hand-off stand alone, with each claim backed by its command and output line, and every skip named?

## Sources

See `sources.md`, entries Anthropic (*How Claude remembers your project*, *Best practices for Claude Code*, *Claude
Code in large codebases*, *Effective context engineering for AI agents*); OpenAI (*Custom instructions with
AGENTS.md*); agents.md; Gloaguen (*Evaluating AGENTS.md*); McMillan (*Instruction adherence factorial study*); Nigh
(*How to write a great agents.md*); Various (*Agent files*); Ronacher (*Agentic Coding Recommendations*); Owner
(*Global working rules*, *Skills*).
