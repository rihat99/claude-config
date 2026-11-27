# 8. Decisions, compatibility, releases

Write down what the project is not and why each shaping decision was made, so that settled questions stay settled.
Define the public surface in one place and give each kind of artifact its own compatibility horizon, checked by a
machine: a table of compatible changes, an API diff against the last release, deprecations that fail a test at
their removal version. File formats carry the longest promise: every file a release wrote stays readable by every
later release. A release is a tag, a closed changelog section and a checklist run over the full matrix, and
downstream projects pin it.

## Principles

### 8.1 Write the scope, the non-goals and the bar for inclusion on one page [Law 6]
**Why.** A project stays coherent by refusing good ideas outside its job. A written non-goal turns a recurring debate
into a link, and an inclusion bar says what a contribution must prove before anyone argues taste: an oracle test,
support for every joint kind and batch shape, performance across the working-set range, and a whole that is simpler
afterwards. Agents need the page most, because without it they add whatever is possible. The page is short and
linked from the README and the agent file.

**Example.** The form (a sketch for `BetterRobot`, which has no such page):
```markdown
# Scope

BetterRobot computes kinematics, dynamics and least-squares solutions for robots, batched and
differentiable in PyTorch.

## Non-goals
- Simulation: it evaluates dynamics; it does not step time.
- Motion planning and task scheduling.
- A second numerical backend (decision 0001).

## Inclusion bar
A feature lands when it has an oracle test, works for every joint kind and batch shape, keeps the
hot paths free of host syncs, and removes more from its callers than it adds to the library.
```

**Check.** Review question: is this feature inside the scope page, and does it meet each line of the inclusion bar?

### 8.2 Write every decision record to one template, and change only its status once it is accepted [Law 6]
**Why.** Without the reason, a later reader can only accept a decision blindly or reverse it blindly. A decision
record is the one document that proposes, argues and records a decision: one or two pages, numbered in sequence and
never renumbered. It starts in status Proposed and becomes Accepted when the owner accepts it with its open questions
resolved; after that only its status changes, and a reversed decision is superseded by a later record, never
deleted. The template forces the questions a reviewer would ask anyway: what it costs, how others solved it, how it
reads at a call site, what breaks, and what keeps it true. 11.6 lists the changes that need one.

**Example.** The template:
```markdown
# NNNN Title

**Status:** Proposed | Accepted | Superseded by NNNN. **Date:** YYYY-MM-DD

## Context         the concrete failure or need, 3 to 6 lines
## Decision        one sentence: "We will ..."
## Example         the call site or the file as if the decision had shipped
## Consequences    what it costs, including the drawbacks: the reasons not to do it
## Alternatives    each option with its prior art (how Pinocchio, Drake or MuJoCo do it), argued, not listed
## Compatibility   what breaks, the migration, and whether the decision can be undone without breaking users
## Enforcement     contract ids, tests and lints that keep it true
## Open questions  empty before Accepted
```
`BetterRobot/docs/contracts/decisions/0002-immutable-fk-state.md` fits on one screen: its context names the
failures of the old design, its decision is one sentence, its consequences include the cost ("Each query
allocates"), and its enforcement names the tests.

**Check.** A test parses every record: the required headings exist, the status is an allowed value, the numbers are
contiguous, and the resolver test (7.8) checks every enforcement path.

### 8.3 Keep a list of commonly rejected ideas, with one line of reason and a link each [Law 6]
**Why.** The same ideas come back, most often from agents with no history. A list next to the decision records makes
reopening a question cost evidence the record did not weigh, instead of repetition. Each entry names the idea, the
reason in one line, and the record or contract that settled it. The agent file links the list.

**Example.** A list drawn from BetterRobot's accepted records (sketch):
```markdown
# Commonly rejected

Reopening one of these needs evidence the record did not weigh, not preference.

- A second backend (Warp lanes, JAX, custom CUDA kernels): doubles every test and every contract. 0001
- A mutable `Data` filled by the algorithms: stale reads, autograd hazards, call-order coupling. 0002
- Residual classes or cost objects: data held in instances, heavier to compose. 0003
- Another viewer (meshcat, rerun, native OpenGL): weaker recording, duplicate state, or a display on the GPU host. 0004
- Rotation vectors so that `nq == nv`, or `q + v` on configurations: singular at pi; use `integrate`. 0005
- Scalar-first `wxyz` quaternions: the layout is `xyzw` everywhere. C-NAME-3
```

**Check.** Review question: is this idea on the list, and if so, what evidence does it add?

### 8.4 Define the public surface in one place, both sides of it, and a compatibility horizon for each kind of artifact [Law 5]
**Why.** A version number promises nothing until "public" is defined, and every observable behaviour ends up depended
on by someone. The public surface is what a project promises to strangers: every dotted path whose segments are
each listed in their parent's `__all__` (1.6), the file formats, the command lines, and the documented behaviour of
each; for an application, its command line, config keys, output files and output tree. This page is its one
definition, with two sides: what users may do and what maintainers promise in return. A feature reached by accident
becomes a promise by use, so an experiment sits behind an explicit opt-in, with an owner and the version at which it
is promoted or removed. A file on a user's disk cannot be patched the way code can, so each kind of artifact gets its
own horizon. The coupling standard (1.3) covers shapes, layouts, identifiers and file formats; Python names follow
the deprecation path (8.9).

**Example.** The page:
```markdown
Public         a dotted path whose every segment is listed in its parent's __all__
Canonical      the root for a first-level name, else the package whose __all__ lists it
Users may      call public names; implement JointModel; add a format with io.register_parser
Users may not  subclass concrete classes; rely on dataclass field order; import tests/, examples/, tools/
Experimental   <package>.experimental.<name>: an owner, and the version that promotes or removes it

- Python API before 1.0: a minor release may break a public name after one minor release of deprecation.
- Python API from 1.0: breaks only in a major release.
- File formats: every file a release wrote stays readable by every later release.
- Numerical results: within the documented tolerance of the named oracle; bitwise only where a test pins it.
- Coupling standard (shapes, pose layout, axes, frame identifiers): additions only.
```
`BetterRobot/docs/contracts/08-extension-points.md` writes two of these lines (C-EXT-3 and C-EXT-6); the lines for
formats, numbers and experiments are missing.

**Check.** A test fails when a package has no entry on the page, and when the package version reaches an
experiment's promote-or-remove version. Review questions: is this name public, experimental or internal, and which
horizon covers this change?

### 8.5 List the compatible changes, and treat every unlisted change as breaking [Law 5]
**Why.** A table of compatible changes can be decided in review and by tools; a list of forbidden changes always
misses a case. The table goes per kind of declaration, and every `Literal` or enum states whether its set of options
is open (callers must accept unknown values) or closed (callers may match exhaustively). An addition is compatible
only if it never shadows user code; a method added to a base class that users subclass can shadow one of theirs.

**Example.**
```markdown
| Change | Class |
|---|---|
| Add a function, class or module | compatible |
| Add a keyword-only parameter with a default | compatible |
| Add a field to a frozen dataclass, keyword-only with a default | compatible |
| Add an option to an open `Literal` set | compatible |
| Add an optional field to a file format, ignored by older readers | compatible |
| Add, remove or reorder a positional parameter | breaking |
| Change a default value | breaking (behaviour) |
| Remove or rename a public name, field or parameter | breaking: deprecate first (8.9) |
| Add an option to a closed set | breaking |
| Change a result beyond its documented tolerance | breaking |
| Change the meaning or layout of an existing file field | breaking: raise `format_version` (8.7) |
```

**Check.** The label on each change (8.6) matches these rows. Review question: is this change in a compatible row? If
not, it is breaking.

### 8.6 Diff the public API against the last release in CI, and label every change major, minor, patch or none [Law 8]
**Why.** People miss a removed default or a reordered parameter; an API diff does not. The label makes the author
classify the change against the table of 8.5 before review, and it drives the version and the changelog. Major means
breaking, minor a compatible addition, patch a fix. From 1.0 the label is the version bump. Before 1.0 the diff
still blocks: a major change raises the minor version, and every other change raises the patch version. The diff
needs a baseline, so every release is a tag (8.10).

**Example.** One command against the last tag, in CI, with `griffe` in the dev dependency group:
```bash
uv run griffe check better_robot --search src --against v0.2.0
```

**Check.** CI runs the diff on every change and fails on a break that is not labelled major. Review question: does
the label match the rows of 8.5?

### 8.7 Treat every file format as public: a written spec, a format name, a version that readers check, and added fields ignored [Law 5]
**Why.** Data outlives code: a file is read by code that did not exist when it was written, and a file on a user's
disk cannot be patched. A `format` field says what the file is, so a loader never guesses. One integer,
`format_version`, rises only when the meaning or layout of an existing field changes. A reader that knows versions up
to N reads every file whose version is at most N, and refuses a later one with an error that names both versions and
the fix. Additions are optional fields: a reader ignores fields that a later release added to the format, and a
removed field's name is never reused. A config is not such a file: its loader rejects unknown keys (12.1). A spec
page (fields, dtypes, shapes, units, axes, pose layout) is written before the loader, and the loader validates
against the same spec. A public writer is safe to repeat: the same inputs give the same bytes, and an existing file
is replaced atomically (12.3).

**Example.** The check every loader runs first (sketch):
```python
FORMAT = "better_human.mhr"
FORMAT_VERSION = 1  # the highest version this release reads and writes


def check_format(data: Mapping[str, Any], *, source: str) -> None:
    """Refuse a file of another format or of a later version; fields added by later releases are ignored."""
    if str(data.get("format")) != FORMAT:
        raise FormatError(f"{source}: format={data.get('format')!r}, expected {FORMAT!r}")
    if int(data["format_version"]) > FORMAT_VERSION:
        raise FormatError(f"{source}: format_version={int(data['format_version'])} is later than {FORMAT_VERSION}; "
                          "upgrade better_human to read it")
```
`BetterHuman/src/better_human/families/mhr.py::mhr` names both versions in its error, but it compares the whole
metadata for equality, which leaves no room for a migration (8.8).

**Check.** Per format: a round-trip test; one fixture file per past `format_version`, kept in `tests/`, that every
release must load; and a test that a file with a later version is refused.

### 8.8 Put each change of a file format in one pure migration function, so that core code reads only the latest layout [Law 5]
**Why.** Version branches spread through core code make every reader handle every past layout forever. A chain of
pure functions `migrate_vN_to_vN1(fields) -> fields`, applied at load until the file reaches the latest version,
keeps old layouts out of core code at a fixed cost per change. Each function's docstring is its changelog line.

**Example.** A migration chain (sketch):
```python
def migrate_v1_to_v2(fields: dict[str, np.ndarray]) -> dict[str, np.ndarray]:
    """v2 stores joint rotations as quaternions [qx, qy, qz, qw] (J, 4) instead of matrices (J, 3, 3)."""
    kept = {key: value for key, value in fields.items() if key != "joint_rotation_matrices"}
    rotations = matrix_to_quaternion(fields["joint_rotation_matrices"])  # (J, 4)
    return {**kept, "joint_rotations": rotations, "format_version": np.int64(2)}


MIGRATIONS = {1: migrate_v1_to_v2}


def upgrade(fields: dict[str, np.ndarray]) -> dict[str, np.ndarray]:
    """Apply the migrations in order until the fields reach FORMAT_VERSION."""
    while int(fields["format_version"]) < FORMAT_VERSION:
        fields = MIGRATIONS[int(fields["format_version"])](fields)
    return fields
```

**Check.** A test loads each past-version fixture through `upgrade` and compares it with the latest-version fixture.
A grep finds no comparison of `format_version` outside the migration module and the format's `check_format`.

### 8.9 Deprecate with a replacement and a removal version, and let a test fail when that version is reached [Law 5]
**Why.** A deprecation without an end never ends, and one without a replacement strands its users. The warning names
the replacement, the changelog lists it under Deprecated, and one table in the code lists every deprecated name with
its replacement and removal version. A contract test fails once the package version reaches a removal version while
the name still exists, so removal cannot be forgotten. The end is a version, not a calendar date, because the promise
counts releases and a date breaks bisection.

**Example.** The table and its test (sketch):
```python
DEPRECATIONS: dict[str, tuple[str, str]] = {  # name -> (replacement, removal version)
    "package.old_function": ("package.replacement", "0.4.0"),
}


def test_deprecations_are_removed_on_schedule() -> None:
    current = Version(package.__version__)
    overdue = [name for name, (_, removal) in DEPRECATIONS.items() if current >= Version(removal)]
    assert not overdue, f"remove before releasing {current}: {overdue}"
```

**Check.** The schedule test runs in the fast tier; a second test asserts that each entry emits a
`DeprecationWarning` naming its replacement; the changelog's Deprecated entries match the table.

### 8.10 Release by checklist: close the changelog section, run the full matrix, review the diff since the last tag, and tag [Law 5]
**Why.** A main branch is not a promise anyone can pin, and a long Unreleased section is a release nobody can name.
The checklist is short and run by a person: the release tier, the API diff reviewed for undocumented public names, the
changelog section dated, the version raised, the tag pushed. The docs state the supported Python and torch range of
each release; a patch release never raises a floor, and the matrix tests every floor. Downstream projects pin a
release tag or version, and a commit rev until a library's first release, never a branch, so their results name the
library that produced them.

**Example.** The checklist:
```markdown
- [ ] Changelog: Unreleased becomes `## v0.3.0 (YYYY-MM-DD)`; every Deprecated and Removed entry has its migration.
- [ ] API diff against the last tag reviewed: no public name without a docstring and a changelog line.
- [ ] Release tier green: torch floor and latest, CPU and CUDA, float32 and float64, compile on and off,
      internal checks on, licensed-asset parity.
- [ ] Deprecation schedule test green at the version being released.
- [ ] Tag pushed; downstream pins moved to the tag.
```

**Check.** A test asserts that every `## vX.Y.Z` heading in the changelog has a matching git tag. Review question:
does any `pyproject.toml` that consumes this library pin a branch?

## Application profile

Relaxed:
- No API compatibility promise, API diff, semver label or deprecation table; internal names are renamed outright.
- Decision records may be shorter, and they record method choices as well as architecture.

Not relaxed:
- Output files and configs carry a `format` name and a checked `format_version` (8.7). Output files ignore
  fields added later (8.7); configs reject unknown keys (12.1).
- The scope page (8.1) and the commonly rejected list (8.3) exist, because agents re-propose rejected methods most.
- Each library is pinned as 8.10 says, and a run whose results are published comes from a tagged commit.

## Checklist
- [ ] Is there one page with the scope, the non-goals and the inclusion bar, linked from the README and agent file?
- [ ] Did every change of a kind that 11.6 lists start as a decision record in the template of 8.2?
- [ ] Is there a commonly rejected list, one line and one link per entry, linked from the agent file?
- [ ] Is the public surface defined on one page, with experiments that expire at a version and a horizon per artifact?
- [ ] Is there a table of compatible changes, with every unlisted change treated as breaking?
- [ ] Does CI diff the public API against the last tag, and does every change carry a semver label?
- [ ] Does every file format have a spec page, a `format` name, a checked `format_version`, and added fields ignored?
- [ ] Is every format change one pure migration function, with core code reading only the latest layout?
- [ ] Does every deprecation name its replacement and removal version, with a test that fails on schedule?
- [ ] Is every release a tag with a dated changelog, a completed checklist and tested floors, pinned downstream?

## Sources

See `sources.md`, entries WebKit (*Project Goals*); Swift.org (*Introducing Swift Collections*); Nygard
(*Documenting Architecture Decisions*); Rust project (*RFC template*); Swift project (*Swift Evolution*, *Library
Evolution Support in Swift*, *github-workflows*); Apple (*swift-nio*, *swift-collections*); Go project (*Go 1 and the
Future of Go Programs*); Cox (*Backward Compatibility, Go 1.21, and Go 2*); Drake (*Stability guarantees*);
Preston-Werner (*Semantic Versioning 2.0.0*); Wright (*Hyrum's Law*); Python (*PEP 8*); SQLite (*Database File
Format*, *SQLite As An Application File Format*, *Long Term Support*); Leach (*APIs as infrastructure*); Lacan (*Keep a
Changelog 1.1.0*).
