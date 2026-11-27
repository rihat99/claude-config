# Task intake checklist (anti-lazy validation)

Purpose: the agent must **force** clarification of exactly the points where
agents tend to hallucinate — before any work starts. Order of operations:

1. **Investigate first.** Read the repo, `agent_notes/docs/`, recent task
   folders, git log. Resolve every item below yourself where possible.
2. **Then interview.** For every item still unknown or ambiguous — especially ⚠
   items — ask the user with AskUserQuestion, all at once, at task start (the
   user is present when they give the first prompt). Asking is not a weakness;
   starting on a guess is.
3. **Refuse to start blind.** If deliverable, baseline, or metrics are unknown
   and the user hasn't answered, do not begin the task.

## Checklist

| # | Item | What must be pinned down |
|---|------|--------------------------|
| 1 | Objective | What method/change is being tested; what "success" looks like. |
| 2 | Deliverable | Exact final artifacts: which tables, which visualizations, which comparisons. |
| 3 | ⚠ Baseline | WHICH experiment/config/checkpoint is the baseline; where its metrics/artifacts live. Never invent one. |
| 4 | ⚠ Metrics | Exact metric definitions: which split, which eval protocol, which aggregation. Metric names are ambiguous — confirm definitions, don't guess. |
| 5 | ⚠ Data | Dataset paths and versions, which machine, which splits; where new data/outputs go (usually `/data*/<username>/...`). |
| 6 | Compute | Which GPUs are allowed (check `gpu_free.py`), expected runtime, whether parallel experiments are OK. |
| 7 | Naming | The experiment naming scheme already in use; proposed name = baseline + delta. |
| 8 | Scope | What must NOT be touched; interactions with currently running jobs. |
| 9 | Repo state | Branch to fork from; any uncommitted changes present and whose they are. |
| 10 | ⚠ Prior work | Existing notes/reports on this topic — read them, treat them skeptically (they are prior agents' output, not ground truth). |

## Hallucination hot-spots (always confirm, never assume)

- File/dataset paths that you haven't `ls`-verified.
- Metric definitions and eval protocols.
- Which config the baseline actually used (read the config from disk/git, not
  from a note's claim about it).
- Hyperparameters "everyone knows" — read them from the execution path.

## Mid-task questions

The intake interview is the one moment where blocking questions are always
allowed. Later questions obey working hours (see SKILL.md §6): outside
10:00–22:00 Asia/Dubai — don't wait; conservative choice + logged assumption.
