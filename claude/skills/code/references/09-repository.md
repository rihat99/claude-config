# 9. Repository

Every repository has the same tree: `src/<package>/` for the product, `tests/` mirroring it, and one folder each for
docs, examples, benchmarks and tools. Data, weights and generated output never enter git; the repository says where
they live and reaches them through one resolver. The environment rebuilds from one committed lockfile, and CI runs
the tier commands (6.9) on every push. Working notes and plans live in the notes folder, outside the product, and
every rule that governs the code is tracked.

## Principles

### 9.1 Lay out every repository the same way [Law 2]
**Why.** A reader who knows one repository then knows all of them, and a tool that checks one checks all. The src
layout keeps tests from importing the uninstalled copy of the package. Each kind of file has one home, so a second
home is visible as a defect. The product's entry points live inside the package, where they are importable, typed
and tested; `tools/` holds what is runnable but is not the product. Code or assets that two repositories share live
once, in the lower library.

**Example.**
```text
<repo>/
├── README.md  LICENSE  CLAUDE.md  AGENTS.md   the first files every reader opens; AGENTS.md is one line (10.1)
├── pyproject.toml  uv.lock  .python-version   the environment
├── .gitignore  .pre-commit-config.yaml  .github/workflows/
├── .claude/                                   shared agent settings, rules and skills (10.3)
├── mkdocs.yml                                 the docs site configuration
├── src/<package>/                             the product, including its entry points
├── tests/                                     mirrors src/ (9.2)
├── docs/                                      the documentation site (7.1)
├── examples/                                  short programs a user copies; each runs in CI
├── benchmarks/                                the one home for speed measurements and their thresholds
├── tools/                                     generators, converters, oracle dumps; never imported by src/
└── agent_notes/                               the notes folder (9.7), ignored whole or in part
```
`BetterRobot` measures speed in two homes, `benchmarks/` and `tests/bench/`, and
`BetterRobot/scripts/docs_screenshots.mjs` is a byte-identical copy of `BetterHuman/scripts/docs_screenshots.mjs`.

**Check.** A contract test compares the tracked top-level entries with the allowed set (example:
`tests/contract/test_repository_layout.py`). Review question: does this file have exactly one obvious home?

### 9.2 Mirror `src/` in `tests/`, and give each cross-cutting suite one named folder [Law 2]
**Why.** The test of a module is found by path, without a search. A failing suite names its kind by its folder: a
rule, an oracle comparison, a doc snippet. `tests/support/` holds fixtures and helpers that only this project's tests
import, in a folder pytest does not collect. Stand-ins and property checkers that other projects use ship in the
package instead (1.8, 6.7).

**Example.**
```text
tests/
├── <package>/           one folder per src package, same name
├── contract/            rules as tests (6.1)
├── parity/<oracle>/     comparisons against the oracle, with goldens and their provenance
├── docs/                executes every snippet in README.md and docs/
├── examples/            runs every example headless
└── support/             fixtures and helpers for this project's tests; imported, never collected
```
The oracle suite is `BetterRobot/tests/test_pinocchio/` in one repository and `BetterHuman/tests/parity/` in the
other: one concept, two names.

**Check.** `tests/contract/test_repository_layout.py::test_tests_mirror_src` fails when a package under `src/` has no
folder of the same name under `tests/`.

### 9.3 Keep data, weights and generated output out of git, reach them through one resolver, and track no symlinks [Law 2]
**Why.** History keeps every byte forever, and licensed weights cannot be redistributed. A path only the owner knows
is a path nobody else can use. One resolver function and one environment variable answer "where is it" for the
library, its tests and every application, so all of them find the same files, and ignored files stay out of agent
searches. A tracked symlink over an ignored directory replaces that directory on checkout and deletes what was in
it, and the pattern `models/` matches only a directory, so an ignore file lists both `models` and `models/`.

**Example.** The whole resolver (`BetterVideoReconstruction/bvr/paths.py`):
```python
REPO_ROOT = Path(__file__).resolve().parents[1]
DATA_ROOT = Path(os.environ.get("BVR_DATA_ROOT", REPO_ROOT.parent / "data"))
EXAMPLES = DATA_ROOT / "examples"
```

**Check.** Tests resolve assets through the library's own resolver. A contract test fails on any tracked symlink, and
on any tracked file over 1 MiB that is not on an exception list with its reason.

### 9.4 Rebuild the environment from one committed lockfile, and give one-off tools their own dependencies [Law 10]
**Why.** Reproducing a result starts with reproducing the environment. A committed `uv.lock` is that environment for
every platform, and `uv run` syncs it. Hooks and CI run their tools from the same lockfile (`uv run ruff`), so each
tool has one version. A tool that needs a heavy package (an upstream oracle, a converter) declares it inline with PEP
723 or in its own folder, so the product does not depend on it. A dependency exists only while code imports it, and
`pyproject.toml` names no path outside the repository, because the repository moves.

**Example.** A self-contained tool under `tools/`:
```python
# /// script
# requires-python = ">=3.12"
# dependencies = ["numpy>=2.0", "trimesh>=4.0.0"]
# ///
```
`tracking/BetterRetarget/pyproject.toml` sources `better-robot = { path = "../BetterRobot" }`, which stopped
resolving when the repository moved into `tracking/`.

**Check.** CI runs `uv lock --check`. Review question: which module imports each added dependency?

### 9.5 Run CI on every push and pull request, with the commands the agent file lists [Law 8]
**Why.** A check that runs only by hand does not run. CI is where "rules are code" becomes true for every change, not
only for the careful ones. It runs, on CPU, the lock check, lint, the format check, the full tier, the full tier
again with internal checks on (6.8), the foundation coverage command (6.11) and the docs build.
A project with a GPU runner adds a job for the CUDA tests and the CUDA counters (5.8); a project without one runs them
by hand in the release tier (8.10). An oracle suite that cannot run fails the job instead of skipping (6.5), and a
red CI blocks the merge.

**Example.**
```yaml
on:
  push:
  pull_request:
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: astral-sh/setup-uv@11f9893b081a58869d3b5fccaea48c9e9e46f990  # v8.3.2
      - run: uv lock --check
      - run: uv run ruff check src tests && uv run ruff format --check src tests
      - run: uv run pytest tests -q -m "not bench and not cuda"
      - run: BETTER_ROBOT_INTERNAL_CHECKS=1 uv run pytest tests -q -m "not bench and not cuda"
      - run: >-
          uv run coverage run --branch --source=src/better_robot/lie,src/better_robot/spatial
          -m pytest tests/lie tests/spatial -q
      - run: uv run coverage report --fail-under=100
      - run: uv run mkdocs build --strict
```
`BetterRobot/.github/workflows/ci.yml` triggers only on `workflow_dispatch`, so it never runs on its own.

**Check.** The workflow's `on:` lists `push` and `pull_request`, and branch protection requires the job.

### 9.6 Keep the tree honest: no ghost directories, no stale build output, no second copy [Law 10]
**Why.** Newcomers and agents explore with `ls` and `grep`. A directory that holds only `__pycache__` looks like a
package, and a stale build answers every search with an old layout. When a file moves, nothing stays behind at the
old place. One canonical home per artifact: after each task, an artifact is either brought up to date or moved to the
trash with the trash helper (the global rules).

**Example.** Find ghost directories before a commit:
```bash
find src tests tools -type d -not -path '*/__pycache__*' | while read -r dir; do
  [ -z "$(git ls-files "$dir")" ] && echo "ghost: $dir"
done
```
`BetterRobot/docs/_build/` is an old Sphinx build whose page tree does not match `docs/`.

**Check.** `tests/contract/test_repository_layout.py::test_no_ghost_directories` fails on a directory under `src/`,
`tests/` or `tools/` that contains no tracked file.

### 9.7 Keep working notes and plans in the notes folder, one task folder each, and let nothing tracked depend on them [Law 9]
**Why.** Notes are working memory: plans, state, briefs, reports. They are neither the product nor its documentation.
Work in progress has one home, `agent_notes/tasks/<YYYY-MM-DD_HH-MM>_<slug>/`, and the public plan of the product has
another, the roadmap page; there is no third, such as a tracked `plan/` folder. A plan lets a reader with no history
restart from that file alone, and each step ends in behaviour that can be shown working; work that spans several
files or more than about an hour gets one. When the task closes, each durable result moves into a decision record,
the changelog, a concept page or a roadmap row, `REPORT.md` says where it went, and stale intermediates go to the
trash. A tracked file that cites a note works only on the machine that has it. The agent file says whether the notes
folder is ignored whole or tracked with its bulky subfolders ignored.

**Example.** One task folder:
```text
agent_notes/tasks/2026-10-25_16-43_test_clips/
├── PLAN.md          goal, "done when" commands, context, steps with checks, decisions, closing
├── STATE.md         progress and surprises, updated in place
├── REPORT.md        results, and where each durable result went
├── subagents/       briefs and scratch of helper agents
└── vis/ artifacts/  figures, renders and dumps, ignored by git
```

**Check.** The tracked tree has no `plan/` folder, and `git grep -nE 'agent_notes/\S+\.\w+' -- ':!agent_notes'`
returns nothing. Review question: does each closed task's `REPORT.md` say where every durable result went?

### 9.8 Track every rule that governs the code and every list of known violations [Law 8]
**Why.** A rule in an untracked file binds only the machine that has it: reviewers cannot cite it, CI cannot enforce
it, and a contributor never sees it. A known violation is tracked as a ratchet (6.1), keyed by qualified name; a
dated count in a comment is not a ratchet.

**Example.** `BetterRobot/.gitignore` ignores `DESIGN_RULES.md`, the file that holds "Never silently fall back" and
"No forwarding layers", and a comment in `BetterRobot/pyproject.toml` points at a violation ledger inside the
ignored notes folder.

**Check.** The resolver test (7.8) fails on a cited path that is not tracked. Review question: where is the rule this
comment relies on, and is it tracked?

## Application profile

An application adds `configs/` at the root for its TOML configs (12.1).

Relaxed:
- `examples/` may be empty when the README's run command on a sample input is the example.
- `benchmarks/` exists only for hot loops that have a speed target.
- `tests/` mirrors the stages, not every module (12.6).

Not relaxed:
- Data and outputs out of git, one resolver, no tracked symlinks, one lockfile.
- CI on every push, cited paths that resolve, the notes folder rules, tracked rules.

## Checklist
- [ ] Does the repository have exactly the standard top-level tree, with one home per kind of file?
- [ ] Does every package under `src/` have a folder of the same name under `tests/`, with one folder per suite kind?
- [ ] Are data, weights and outputs out of git, reached through one resolver, with no tracked symlink?
- [ ] Does the environment rebuild from one committed lockfile, with no outside path and no unimported dependency?
- [ ] Does CI run on every push and pull request, with the agent file's commands, and block the merge when red?
- [ ] Is the tree free of ghost directories, stale build output and second copies?
- [ ] Do notes and plans live in task folders of the notes folder, with no tracked file citing them?
- [ ] Is every rule and every list of known violations tracked, as text and as a ratchet test?

## Sources

See `sources.md`, entries PyPA (*src layout vs flat layout*); Astral (*uv: project layout and lockfile*); Python
(*PEP 723*); GitHub (*About large files on GitHub*); Anthropic (*Claude Code in large codebases*, *Best practices for
Claude Code*, *Effective context engineering for AI agents*); Ronacher (*Agentic Coding Recommendations*); DrivenData
(*Cookiecutter Data Science*); Mineault (*The Good Research Code Handbook: setup*); OpenAI Cookbook (*Using
PLANS.md*); Owner (*Global working rules*, *Skills*).
