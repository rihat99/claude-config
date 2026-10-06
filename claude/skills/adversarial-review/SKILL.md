---
name: adversarial-review
description: Independent adversarial review of important code, plans, experiment results or conclusions by a clean-context, read-only Opus agent at max effort, followed by triage and fixes. Use before declaring important work done, when the user asks for a critique, review, second opinion or red-team, or when a number or conclusion will drive a decision. Not for trivial edits, formatting or typo fixes.
---

# Adversarial review

The reviewer is the pinned `adversary` agent (`~/.claude/agents/adversary.md`): latest Opus, max effort, read-only, fresh context. The point of this skill is independence: the reviewer did not write the work and does not see this conversation. You stay the integrator and own the verdict.

## 1. Scope

Decide what is under review and write it down as claims that can be false:
- Code: a diff (`git diff <base>..HEAD`), a file set, or a function.
- A result: the metric table, the data it came from, the exact command/config that produced it.
- A plan or design: the goals, the chosen approach, the alternatives rejected.
- A conclusion: the statement plus every piece of evidence it rests on.

Skip the review for mechanical changes (renames, formatting, dependency bumps).

## 2. Write the brief

Save a self-contained brief to the session scratchpad (or the project's notes folder when it has one), e.g. `review_brief.md`:

```
# Review brief — <topic>
Goal of the work: ...
What is under review (absolute paths, commit range, commands): ...
Claims to attack (numbered): ...
What "wrong" would look like: ...
How to run / reproduce: ...
Out of scope: ...
Scratch path you may write to: <scratchpad>/review_<topic>/
```

Include everything the reviewer needs; it cannot ask you questions. Don't include your own opinion of the work's quality.

## 3. Spawn the reviewer

Use the Agent tool with `subagent_type: adversary` and the brief path. Never pass `model`; it is pinned. Never reuse (SendMessage) an agent that helped produce the work.

Lenses to request explicitly, one per spawn for big reviews (run 2–3 in parallel in one message) or all at once for small ones:
- **Correctness**: logic, corner cases, concurrency, shapes/units, off-by-one, failure paths.
- **Evidence**: do the numbers follow from the data and the code path? Baselines, leakage, cherry-picking, seeds, statistical noise.
- **Simplicity**: what could be deleted; over-engineering; hidden complexity.
- **Reproducibility**: can a stranger run it from the brief alone?

Ask for the agent's fixed output format (verdict, ranked findings with evidence and a verification step, open questions, nits).

## 4. Triage

For every finding, check it yourself: reproduce it, read the code, rerun the number. Classify each as **confirmed**, **refuted** (say why), or **unclear** (what would settle it). Fix confirmed blockers and majors. Minor and nits: fix if cheap, otherwise list them.

## 5. Second round (only if something was a blocker or major)

Spawn a fresh `adversary` with the original brief, the findings, and what you changed. Instruct it to re-verify the fixes and look for regressions, not to re-list the old findings. Stop after three rounds at most; remaining disagreements go to the user.

## 6. Report to the user

Keep it short and honest:

| # | Finding | Severity | Status | What changed |
| - | ------- | -------- | ------ | ------------ |

Then: the verdict, residual risks, and anything the reviewer could not settle. Include refuted findings with the reason; don't hide them. For ML results give raw metrics and the execution path, not just the headline number.

## Rules

- The reviewer is read-only; you make every change.
- The user's own conclusions are also fair game for the reviewer.
- Nothing is ground truth: not notes, not previous agents, not the reviewer. Verify before you act on a finding.
