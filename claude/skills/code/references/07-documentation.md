# 7. Documentation

Each page is one of four kinds and opens with its short rule; each code block runs in CI and shows its real output;
each claim is backed by a test, and each number names its oracle and the command that produced it. The public
surface, the first screen of the docs and the contracts are ideal before they land (11.1); every other page is held
to the internal bar and must be true. Code is cited by path and symbol, which one test resolves, never by line
number. Pages speak in the present tense to a reader with no history; history lives in the changelog and the
decision records.

## Principles

### 7.1 Write each page as exactly one of four kinds: tutorial, how-to guide, reference, or explanation [Law 9]
**Why.** Each kind answers one need. A tutorial is a lesson that carries a beginner to a working result; a how-to
guide solves a stated problem for someone who knows the basics; reference states facts and mirrors the structure of
the code; explanation answers why. A page that blends kinds serves no reader: the tutorial stalls on theory, the
reference turns into a story. The folder names the kind, so the reader knows before opening. Material for
maintainers (contracts, decision records) is reference in its own folder. A folder is created with its first page,
never as an empty skeleton.

**Example.** One folder per kind (`BetterRobot/docs/`):
```text
docs/getting-started/   tutorial       first-model.md, forward-kinematics.md, inverse-kinematics.md, ...
docs/guides/            how-to         load-a-robot.md, write-a-term.md, fit-a-clip.md, ...
docs/reference/         reference      api/, changelog.md, glossary.md, roadmap.md
docs/concepts/          explanation    architecture.md, model-and-state.md, optimization.md, ...
docs/contracts/         reference for maintainers: rules C-*, decisions/0001..0008
```

**Check.** Review question: which of the four kinds is this page, and does any section belong to another kind?

### 7.2 Make the README's first screen say what the project is, prove it, install it, and run one example with its real output [Law 1]
**Why.** The first screen decides whether a reader continues, and agents copy what they find there. The order is
fixed: one sentence of what it is, visual proof, install, one runnable example of about ten lines with its printed
output, and where to go next. Unavoidable setup, such as licensed weights, shrinks to one line on the first screen
with a link to the rest, and the first example uses something that ships. Prose, badges or testimonials before the
first example push the proof off the screen.

**Example.** `BetterRobot/README.md` has a one-paragraph pitch, a GIF of 64 IK solves, a docs link, install, one
batched IK program, its output, and "Where next". The program ends:
````markdown
print(float((reached[:, :3] - targets[:, :3]).norm(dim=-1).median()))
```
```output
3.1075885246701783e-12
```
````

**Check.** A docs test asserts that the README's first `python` block, followed by an `output` block, starts within
the first 40 lines. Review question: could a reader who stops at the first screen run something and see it work?

### 7.3 Run every code block of the README and docs in CI, and check its printed output [Law 8]
**Why.** Docs that execute cannot rot, and an example that ran is the only kind an agent should copy. An `output`
block shows the reader what to expect and makes the number true by construction. Opting a block out is an explicit
tag with a reason, and rare. The same test checks every image, video and link that the page references.

**Example.** Each page runs in a fresh interpreter, on CPU, with a recording stand-in in place of the viewer server
(`BetterRobot/tests/docs/test_snippets.py`; `BetterHuman/tests/docs/test_snippets.py` does the same):
```python
"""Execute the Python snippets in ``docs/**/*.md`` and ``README.md``; check that every referenced image exists."""

# Fence info string: ```python [tags...]; a ``{ .no-run }`` attribute opts the block out of execution.
```

**Check.** The snippet test runs in the full tier. Review question: does every `{ .no-run }` block say why it cannot
run?

### 7.4 Claim only what a test or a run shows, and give every number its oracle, conditions and command [Law 8]
**Why.** An honest page lets the reader trust each line. "Fast", "accurate" and "robust" are claims; "median position
error 3.1e-12 over 64 solves in float64" is a fact. The docs state each gate's threshold and the worst measured
value, so the reader sees the margin. A number in a results table carries the command that reruns it and the run
directory whose run manifest records it (12.2); it comes from a run of a tagged commit, and a tool copies it from the
run manifest, so nobody types it. "Enforced by X" is true only when X fails on a violation; a page that overstates
enforcement is a bug in the page.

**Example.** A results row with its command and its run (sketch):
```markdown
| Clip | Joint error (mm) | Run |
|---|---|---|
| amass_cmu_88_06 | <from run manifest> | `runs/2026-10-25_16-43-02_retarget/` |

Command for each row: `uv run python -m betterretarget.retarget --clips <clip>`
```
Anti-example: C-TENS-3 says its enforcer checks that each docstring "contains `shape (`"
(`BetterRobot/docs/contracts/02-tensors.md`), but `BetterRobot/tests/contract/test_docstrings.py` checks only that a
docstring exists.

**Check.** A tool regenerates each results table from the run manifests, and CI fails when the page differs. Review
question: which test, benchmark or run produces each number on this page, and does each "enforced by" point at a
check that fails on a violation?

### 7.5 Open every guidance page with its short rule, then the reason, then the details [Law 9]
**Why.** Readers and agents read the top of a page and stop. The rule first lets the reader who stops after one
paragraph act correctly; the reason lets them apply it to a case the page did not foresee; the tables and examples
below make it concrete. An explanation page opens with what the reader will know at its end.

**Example.** `BetterRobot/docs/index.md` opens:
```markdown
BetterRobot is a PyTorch-native robotics library. After this page you will know what the library
is made of, see one complete inverse-kinematics (IK) solve on a batch of targets, and know which
section of the docs to open next.
```

**Check.** Review question: does the first paragraph alone tell the reader what to do?

### 7.6 Open each module whose behaviour is not obvious from its code with a design note, and keep the note true [Law 9]
**Why.** Numerical code is full of defensible choices: which norm, which branch near a singularity, which tolerance
per dtype, what NaN means. Written at the top of the module, they stop the same question from being reopened and
tell callers what is promised. A design note is required where behaviour is not obvious from the code and
encouraged elsewhere. It states what the module computes and in which conventions, its numerical semantics, its
non-goals, and the reason for each surprising choice with the alternative it beat; measured timings belong here too,
not in an agent file. The change that changes the behaviour updates the note, and a note that disagrees with the
code is a bug.

**Example.** `BetterRobot/src/better_robot/lie/so3.py` (abridged):
```python
"""SO(3) group operations on ``(..., 4)`` unit quaternions ``[qx, qy, qz, qw]`` (scalar last).

Tangents are ``(..., 3)`` rotation vectors ``[wx, wy, wz]`` (axis times angle, radians). ``compose(a, b)`` equals
the matrix product ``R_a @ R_b``; ``inverse(q)`` is the conjugate. ``exp`` maps a rotation vector to a quaternion
and ``log`` returns the rotation vector with angle in ``[0, pi]``; ``q`` and ``-q`` give the same ``log``.
"""
```

**Check.** Review question: does this change alter a behaviour that the module's design note describes, and does the
same change update the note?

### 7.7 Keep one short codemap that names the parts, shows how a call flows, and states the invariants as absences [Law 9]
**Why.** A codemap is a map of the country, not an atlas: it names modules and types so the reader can search for
them, and it shows the path of one call. Its most valuable lines are absences ("nothing in the core imports the
viewer"), because no single file can show them, and agents break exactly those rules. Names, not links: links go
stale, names stay searchable. A fact copied by hand drifts, so each absence names its enforcer, and the layer section
is generated from the edge table (1.1) or tested against it. The agent file copies absences from here, never from
memory.

**Example.** Two absences, each with its enforcer (the form, after `BetterRobot/CLAUDE.md` and
`BetterRobot/src/better_robot/optim/CLAUDE.md`):
```markdown
- Nothing in the computational core imports `viewer` (tests/contract/test_layer_dependencies.py).
- Nothing inside a solver `step` reads a tensor back to Python (tests/contract/test_hot_path_lint.py).
```
Anti-example: `BetterHuman/CLAUDE.md` writes the layering by hand as `core -> families -> terms / viz`, while its
edge table (`BetterHuman/tests/contract/test_layer_dependencies.py`) lets `terms` import only `core` and also lists
`io`.

**Check.** A docs test renders the layer section from the edge table, or fails when the two differ. Every invariant
names its enforcer, and the resolver test (7.8) checks that the path exists. Review question: what must never import
what, and where is it written?

### 7.8 Cite code as `path::symbol`, check every cited path with one test, and never cite a line number [Law 9]
**Why.** A line number drifts with every edit above it, and a renamed file leaves dead paths in docs, docstrings,
tests, hooks, workflows and configs. A symbol is searchable and checkable. One resolver test scans every tracked text
file (Markdown, Python, TOML, YAML and JSON, the hook configuration included) for repository paths and
`path::symbol` citations, and fails on a path that is not tracked or a symbol its file does not define. A path under
another repository's name is that repository's to check. The resolver is the one path check a repository needs:
agent files, hooks and decision records are covered by it.

**Example.** The resolver (sketch):
```python
CITED = re.compile(
    r"(?<![\w./-])"  # a path under another repository's name (`BetterHuman/tests/...`) is left to that repository
    r"((?:src|tests|docs|tools|examples|benchmarks)/[\w./-]+\.(?:py|md|toml|ya?ml|json))(?:::([\w.]+))?"
)


def _defines(path: str, symbol: str) -> bool:
    name = symbol.split(".")[-1]
    return re.search(rf"^\s*(def|class) {name}\b|^{name}\b", (ROOT / path).read_text(), re.M) is not None


def test_cited_paths_resolve() -> None:
    """Every repository path and ``path::symbol`` cited in a tracked text file exists."""
    listing = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True, check=True)
    tracked = set(listing.stdout.split())
    dead = [
        f"{page}: {match[0]}"
        for page in sorted(tracked)
        if page.endswith((".md", ".py", ".toml", ".yml", ".yaml", ".json"))
        for match in CITED.finditer((ROOT / page).read_text())
        if match[1] not in tracked or (match[2] and not _defines(match[1], match[2]))
    ]
    assert not dead, "cite a tracked path or path::symbol:\n" + "\n".join(dead)
```
It catches what each repository hides: the docstring of
`BetterRobot/src/better_robot/kinematics/state.py::_validate_q` cites `docs/conventions/contracts.md`, which does
not exist, and the pre-push hook in `BetterRobot/.pre-commit-config.yaml` runs
`tests/contract/test_pluggable_protocols.py`, which is `test_protocols.py`.

**Check.** The resolver test runs in the fast tier, and a lint fails on `.py:<digits>` in tracked text files.

### 7.9 Write in the present tense for a reader who has no history [Law 9]
**Why.** The reader is a person days later or an agent with no context. Session history, plan codes, "no longer",
"was moved", and pointers into files the reader cannot see tell them nothing they can act on, and rot the day they
are written. State the fact as it holds and its reason; history belongs in the changelog and the decision records,
open work in a tracked task list. The global rules ban progress notes in code; this rule extends the ban to docs,
agent files, config comments and test docstrings.

**Example.** Sentences from `BetterRobot`, each with its present-tense form:
```text
src/better_robot/lie/CLAUDE.md   "PyPose was removed in P10-D."
                                 -> "so3.py and se3.py are the only Lie implementation."
pyproject.toml                   "# Enabled above with open violations listed in the task ledger (p1_violations.md):"
                                 -> name a tracked ratchet, or the command that lists them (ruff check --statistics)
tests/bench/README.md            "... is no longer in this directory (it was moved to the repository `trash/`)"
                                 -> delete the sentence
```

**Check.** A lint greps docs, agent files and comments for plan codes (`P\d+-[A-Z]`), "no longer", "was moved",
"recently", and paths into the notes folder. Review question: would a reader who has never seen this project's
history understand every sentence?

### 7.10 Keep the changelog for humans: an Unreleased section on top, entries grouped by change type, one user-facing line each [Law 5]
**Why.** A changelog answers one question: what must I change to upgrade? Grouping by type (Added, Changed,
Deprecated, Removed, Fixed, Security) answers it at a glance, and every deprecation and removal carries its
migration. Implementation detail belongs in commits and decision records. An entry that makes a promise links the
test that pins it.

**Example.** `BetterRobot/docs/reference/changelog.md` groups by area in paragraphs that mix the change with its
implementation. The same entries in the rule's form:
```markdown
## Unreleased

### Added
- `collision.RobotCapsules`, `capsule_capsule` and `self_capsule_distances`; `self_collision_pairs` takes capsules.

### Changed
- `inverse_dynamics` and `mass_matrix` include `model.armature (nv,)` (motor inertia; MJCF `armature`, zero from URDF).
- `RobotSpheres.centers`, `RobotCapsules.segments` and `inverse_dynamics` have bitwise reproducible CUDA gradients
  (`tests/collision/test_collision.py::test_cuda_backward_is_bitwise_reproducible`).

### Fixed
- The MJCF parser places capsule and cylinder `fromto` geometry as MuJoCo's compiler does.
```

**Check.** A changelog test asserts that every heading under a release is one of the six types, and that every
Deprecated or Removed entry names its replacement.

## Application profile

Relaxed:
- No tutorial or how-to tree: the docs are a README, one explanation page with the stage table (12.6) and a
  runbook.
- A changelog is kept only when other projects consume the outputs.

Not relaxed:
- The README's first screen shows one command on a sample input with its expected output (7.2).
- A results table gives the exact command and the run directory for each row (7.4).
- Snippets execute, pages are in the present tense, code is cited by path and symbol, and design notes follow 7.6.
- No tracked page contains an absolute path (12.4).

## Checklist
- [ ] Is this page exactly one of tutorial, how-to guide, reference or explanation?
- [ ] Does the README's first screen hold what, proof, install, one example and its real output?
- [ ] Does every code block run in CI with its output checked, and does every opt-out say why?
- [ ] Is every claim backed by a named test or run, and does every number carry its oracle, conditions and command?
- [ ] Does every guidance page open with its short rule, then the reason?
- [ ] Does each module with non-obvious behaviour open with a design note that matches the code?
- [ ] Is there one short codemap whose layer section matches the edge table, with absences that name enforcers?
- [ ] Is every citation a `path::symbol` or a path that the resolver test checks, with no line numbers?
- [ ] Is every sentence in the present tense, free of session history and of pointers into unseen files?
- [ ] Is the changelog grouped by change type, with an Unreleased section and a migration for every removal?

## Sources

See `sources.md`, entries Procida (*Diátaxis*); Nigh (*How to write a great agents.md*); pydantic
(*pytest-examples*); Karpathy (*nanoGPT*); Papers with Code (*Releasing research code*); Paul (*How Stripe builds
interactive docs with Markdoc*); Rams (*Ten principles for good design*); Apple (*xnu documentation*,
*swift-numerics*); antirez (*Writing system software: code comments*); Kladov (*ARCHITECTURE.md*); Various (*Agent
files*); Lacan (*Keep a Changelog 1.1.0*).
