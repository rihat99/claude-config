# 6. Testing

Tests are the executable form of every promise a project makes. A rule that must always hold is a contract test or a
lint whose message carries the fix, a fixed bug has a test that fails without the fix, and a numerical result names
its oracle and its tolerance. Gates fail when they cannot run, and nothing is skipped, xfailed or loosened to get
green. Randomized tests replay from a seed, each property is checked once for every implementation, and every tier
is one command with a measured time.

## Principles

### 6.1 Write every rule that must always hold as a contract test or lint whose failure message names the rule and the fix [Law 8]
**Why.** A prose rule is a reminder; a failing check is a fact that needs no reviewer. The failure message is the
interface: it names the rule, what was found and where, and how to fix it, so an agent repairs the code without
opening the contract. Guard the rule as it stands, never a past event. Known violations go into a ratchet: a
shrink-only list keyed by qualified name, never by `file:line`, with a test that fails on stale entries. A correction
made twice becomes a check, not emphasis: capitals and "IMPORTANT" in an agent file make agents apply a rule too
widely and still miss it where it matters. The ladder runs from a line in the agent file to a lint or a contract
test, and to a hook only when the rule must block before a commit.

**Example.** A ratchet with its stale-entry test (`BetterHuman/tests/contract/test_keyword_only.py`, abridged):
```python
# Current violations (qualified name -> positional count). Shrink, never grow.
KEYWORD_ONLY_ALLOWLIST: dict[str, int] = {
    "better_human.core.rig.Rig.bake": 4,  # core/rig.py:47
}


def test_allowlist_has_no_stale_entries() -> None:
    counts = _public_callables()
    stale = [name for name, count in KEYWORD_ONLY_ALLOWLIST.items() if counts.get(name) != count]
    assert not stale, f"fixed or renamed; remove from KEYWORD_ONLY_ALLOWLIST: {stale}"
```
The key still resolves, while the line comment has drifted: `Rig.bake` is defined further down. That drift is why a
ratchet is keyed by name only.

**Check.** Every contract cites an enforcer that exists, and a matrix test checks it (example:
`tests/contract/test_contract_matrix.py`). Review questions: does the failure message say which rule broke and what
to do? Is this the second time a reviewer made this correction, and where is the check?

### 6.2 Fix a bug only together with a test that fails without the fix [Law 8]
**Why.** The test is the only executable record that the mistake stays fixed, and writing it first proves the bug is
understood. The global rules give a just-fixed bug as a reason to write a test; this rule requires one, except for
research or one-off scripts, which the global rules exempt unless the owner asks. Run on the parent commit, the test
must fail, which shows that it tests the bug and not something nearby.
When no test can be built (a race on hardware that CI does not have), the commit carries a `No test:` line with the
reason, and the reviewer judges it. The test is named for the behaviour, and its docstring states the case that
broke.

**Example.** A fix commit that states the defect, its cause, the fix and what the test checks (`BetterRobot` commit
`e4beef0`, body abridged):
```text
skeleton_spec read joint.axis, which is None for JointRX/RY/RZ and
PX/PY/PZ (axis kept in a ClassVar), so every x- or y-axis joint was drawn
along +z (22 of the G1's 29 joints, 90 deg off). It now reads
model.structure.joint_axes. The regression test checks every marker
against a finite difference of forward kinematics on all axis kinds and
on the G1 (the Panda only has z axes).
```
Its test, `tests/viewer/test_robot.py::test_skeleton_markers_lie_on_the_forward_kinematics_joint_axes`, runs on a
model that the test builds with every axis kind, and again on the G1.

**Check.** Review question: does the test fail on the parent commit? The reviewer runs it there, in a scratch
worktree. The commit message names the test on a `Test:` line or carries a `No test:` line (11.5).

### 6.3 Name the oracle of every numerical test, and compare intermediate results in order [Law 8]
**Why.** A number without an independent reference is a guess. For a re-implementation the upstream library is the
oracle; for an analytic derivative, autodiff; for a fast path, the plain path (1.9). Compare in float64 with every
random source fixed to test the math, and in each supported dtype with that dtype's tolerance to test the precision.
Compare intermediate results in order (joint transforms, then frame poses, then Jacobians, then dynamics), so that a
failure names the first quantity that diverged. A tolerance depends on the dtype and carries its reason; a parity
failure is fixed in the code, never in the tolerance.

**Example.** Tolerances written as part of the contract, with the reaction to a failure
(`BetterRobot/docs/contributing/testing.md`):
```markdown
| Inputs | Typical `atol` |
|--------|----------------|
| float64 | `1e-12` to `1e-9` for kinematics and Jacobians; up to `2e-6` for a few dynamics cases |
| float32 | `2e-6` |

A parity failure means the library changed its answer. Fix the code, not the tolerance.
```

**Check.** Each numerical test module names its oracle in its docstring. Review question: is each tolerance stated
with its dtype and reason, and is it unchanged by this change?

### 6.4 Store each golden with its provenance inside the file, and regenerate goldens only with the committed script [Law 8]
**Why.** A golden is a stored expected output. Without provenance it can be neither audited nor regenerated, and a
golden regenerated from buggy code records the bug as truth. Each golden carries the oracle and its version, the
generator script, a checksum of the input asset, the dtype and the seed, inside the file, so it stays
self-describing when copied. Regeneration is a reviewed diff with a reason. Where a licensed asset cannot ship,
goldens generated from random weights in the same format stand in for it (6.5).

**Example.** BetterHuman's SMPL-X goldens are `.npz` files written by `BetterHuman/tools/parity/smplx/dump_smplx.py`
in its own locked environment; the oracle pin `smplx==0.1.28` lives in that tool's `pyproject.toml`, README and
lockfile, not in the goldens. The rule moves it into each file:
```python
np.savez_compressed(
    output_dir / f"{name}.npz",
    provenance=np.array(json.dumps({
        "oracle": "smplx==0.1.28",
        "generator": "tools/parity/smplx/dump_smplx.py",
        "asset_sha256": weights_sha256,
        "dtype": "float64",
        "seed": None,  # a fixed grid, no random draws
    })),
    **arrays,
)
```

**Check.** A test loads every golden, asserts the provenance keys, and asserts that the generator path exists.
Review question: does a changed golden come with the command that produced it and the reason?

### 6.5 Make every gate fail when it cannot run [Law 7]
**Why.** A skipped oracle reports green while checking nothing. A gate is any test in the fast or full tier (6.9):
`tests/contract/` and `tests/parity/` hold the typical ones, and the CPU counter tests of 5.8 are gates wherever
they sit. The global rules forbid skipping, xfailing or weakening a test to get a green run; this rule extends the
ban to the environment. An oracle is a test dependency, installed with the test tools, and its absence is an error.
Where a gate's input cannot ship, such as licensed weights, the fast and full tiers run it on goldens from random
weights (6.4), and the check against the licensed asset runs in the release tier (6.9), whose command fails when the
asset is absent. A test that needs what those two tiers lack, a GPU or a licensed asset, carries a marker that
deselects it there, and it runs in the job or tier that has what it needs.

**Example.** The parity conftest skips the whole oracle folder when the package is missing
(`BetterRobot/tests/test_pinocchio/conftest.py`):
```python
pin = pytest.importorskip("pinocchio", reason="dev-only dependency")
```
The fix is a plain `import pinocchio as pin`, with `pin` in the test dependency group.

**Check.** A contract test fails on any `skip`, `skipif` or `importorskip` in a test that the fast or full tier
selects. Review question: can this gate report green on a machine where its oracle is absent?

### 6.6 Draw randomized cases from a seeded generator, and keep every seed that ever failed [Law 8]
**Why.** Hand-picked cases test what the author thought of; random kinematic trees (every joint kind, free flyers,
`nq != nv`), batch shapes, dtypes and solver settings find what the author did not. Randomizing solver settings
(damping, iteration counts, tolerances) proves that correctness does not depend on one tuned default. A seed makes
each case replayable (5.1): the fast and full tiers run a fixed seed list, the release tier draws fresh seeds and
prints them, and a failing seed joins the fixed list. One mechanism serves this: generators in the test-support code
that take a `torch.Generator`, and no second randomized-testing framework.

**Example.** A property over random models (sketch; `random_tree_model` and `random_configuration` live in
`tests/support/`):
```python
SEEDS = [0, 1, 2, 3]  # append each seed that ever failed, with the case it broke


@pytest.mark.parametrize("seed", SEEDS)
def test_integrate_difference_round_trip(seed: int) -> None:
    generator = torch.Generator().manual_seed(seed)
    model = random_tree_model(generator=generator, num_joints=12, dtype=torch.float64)
    q = random_configuration(model, batch_shape=(8,), generator=generator)            # (8, nq)
    v = 0.1 * torch.randn(8, model.nv, generator=generator, dtype=torch.float64)    # (8, nv)
    torch.testing.assert_close(model.difference(q, model.integrate(q, v)), v)
```

**Check.** Review question: does every randomized test draw from a seeded generator whose seed appears in the test
id? The release tier's command prints the seeds it drew.

### 6.7 Write each property check once, and run every implementation through it [Law 2]
**Why.** The properties of an abstraction hold for every implementation: a joint's `difference(q, integrate(q, v))`
equals `v`, a Jacobian matches finite differences, a term is invariant under batching. A property checker written
once gives every added joint type or term the whole set in one call and catches the property someone forgot. Where
the space is small, enumerate it and print the case that failed. Minimal and pathological fixtures live beside it:
one joint, only fixed joints, a zero-mass link, an empty batch. When users write their own implementations, the
checker ships in the public surface, like a stand-in (1.8).

**Example.** One checker in place of one copy of the round trip per joint type
(`BetterRobot/tests/data_model/test_joint_models.py` writes `test_revolute_integrate_difference`,
`test_prismatic_integrate_difference` and three more):
```python
@pytest.mark.parametrize("joint", ALL_JOINT_MODELS, ids=lambda joint: type(joint).__name__)
def test_joint_model_properties(joint: JointModel) -> None:
    check_joint_model(joint, dtype=torch.float64)  # identity, round trip, Jacobian vs finite differences
```

**Check.** A contract test asserts that `ALL_JOINT_MODELS` equals the exported joint types. Review question: does
this implementation pass the shared checker, or bring its own copy of a property?

### 6.8 Keep internal invariants as executed checks, and put the ones that read tensor values behind one switch [Law 8]
**Why.** An invariant in a comment rots; an executed one cannot. Structural checks (shapes, index tables, topology)
cost nothing and run whenever an object is built. Checks of the library's own results that read tensor values (finite
poses, unit quaternions, a non-increasing cost) force a host sync, so they live behind one switch per library,
`<PACKAGE>_INTERNAL_CHECKS`, off by default and read once at import. While it is on, performance promises are void,
and CI runs the full suite once with it on. A user's opt-in check of their own input (2.8) is a different tool.
Python `assert` states internal invariants only, never user input, because `python -O` removes it.

**Example.** One switch, one guard (sketch):
```python
INTERNAL_CHECKS = os.environ.get("BETTER_ROBOT_INTERNAL_CHECKS") == "1"  # voids performance promises


def _check_state(state: KinematicState) -> None:
    """Assert finite poses and unit quaternions; reads values, so it runs only in internal-checks mode."""
    if not INTERNAL_CHECKS:
        return
    poses = state.joint_poses  # (B..., njoints, 7)
    if not torch.isfinite(poses).all() or ((poses[..., 3:].norm(dim=-1) - 1).abs() > 1e-5).any():
        raise InternalCheckError("KinematicState holds a non-finite pose or a non-unit quaternion")
```

**Check.** A CI job runs the suite with the switch on. Review question: does any check of the library's own
results that reads tensor values run outside the guard?

### 6.9 Give every test tier one command and a measured time, and run the fast tier before each commit [Law 2]
**Why.** A suite that takes too long gets skipped, and an agent needs a loop it can run after every edit. Three tiers
cover the need. The fast tier (contract tests plus the touched package) runs in seconds before every commit. The
full tier (everything except benchmarks and release checks) runs on every push in CI. The release tier (the full
matrix and the licensed-asset checks, 8.10) runs before a tag. The fast and full tiers run on any machine, with no
licensed asset and no GPU. Every other question (is it clean, do the docs build, does the example run) also has one
command. Each command sits at the top of the agent file with its measured time and exits 0 on the main branch,
because a command that fails on a clean checkout teaches every reader to ignore it.

**Example.** Two tiers with times measured on one CPU machine (`BetterRobot`):
```bash
uv run pytest tests/contract -q                        # fast, about 2 s, plus the touched package's folder
uv run pytest tests -q -m "not bench and not cuda"     # full, about 4 min, every push in CI
```
The lint command in `BetterRobot/CLAUDE.md` fails on the main branch, so every reader learns to skip it.

**Check.** The agent file lists each tier first, with its time, and CI runs the full tier on every push (9.5). Review
question: did this change make the fast tier slower?

### 6.10 Configure the test runner strictly [Law 7]
**Why.** A mistyped marker silently deselects tests, an unknown config key is silently ignored, an xfail that starts
passing hides a fix nobody noticed, an empty parameter set turns a test into a skip that checks nothing, and a
deprecation warning that passes now is an error after the next upgrade. Strict settings turn each of these into a
failure that names itself.

**Example.** The Scientific Python recommendation, plus a failing empty parameter set:
```toml
[tool.pytest.ini_options]
addopts = ["-ra", "--showlocals", "--strict-markers", "--strict-config"]
xfail_strict = true
empty_parameter_set_mark = "fail_at_collect"
filterwarnings = ["error"]
testpaths = ["tests"]
```

**Check.** A contract test reads `pyproject.toml` and asserts these options; each `filterwarnings` exception names
the warning and its reason.

### 6.11 Require full branch coverage of the foundation layer, and behaviour coverage above it [Law 8]
**Why.** A bug in the layer every other package builds on (Lie groups, spatial algebra) spreads everywhere. That code
is small and stable, and full branch coverage reaches the small-angle and near-pi branches that sampled tests miss.
Above the foundation a percentage rewards trivial tests, which the global rules warn against, so the bar is
behaviour: every public function, every documented edge case (2.7) and every fixed bug has a test. The foundation is
named once, in the coverage command, and matches the bottom of the edge table (1.1).

**Example.** The foundation command for `BetterRobot`, which reports 89 % there and fails:
```bash
uv run coverage run --branch --source=src/better_robot/lie,src/better_robot/spatial -m pytest tests/lie tests/spatial -q
uv run coverage report --fail-under=100
```

**Check.** CI runs the foundation coverage command on every push (9.5). Review question: which test takes this
branch?

## Application profile

Relaxed:
- No coverage target (6.11) and no internal-checks switch (6.8).
- Property checkers only for the application's core transforms (6.7), and randomized tests are optional (6.6).

Not relaxed:
- Every bug fix carries a test, except in research or one-off scripts (6.2).
- A smoke test runs the whole pipeline on a tiny input in the full tier (12.7).
- A golden of one fixed input from the last accepted run, with its provenance (6.4), guards the results.
- Gates never skip (6.5), and the runner is strict (6.10).

## Checklist
- [ ] Is every contract a test or lint whose message names the rule and the fix, with violations in a ratchet?
- [ ] Does every bug fix come with a test that fails on the parent commit, or a `No test:` line with its reason?
- [ ] Does every numerical test name its oracle, compare intermediate results in order, and state its tolerances?
- [ ] Does every golden carry its provenance inside the file, and was each changed golden produced by its script?
- [ ] Does every gate fail, never skip, when its oracle or asset is absent?
- [ ] Do randomized tests draw from seeded generators, with every failing seed kept?
- [ ] Does every implementation of a protocol pass the one shared property checker?
- [ ] Do the library's own value-reading invariant checks run only behind the internal-checks switch?
- [ ] Does each tier have one command and a measured time at the top of the agent file?
- [ ] Does the runner config set strict markers, strict config, strict xfail, warnings as errors and a failing
  empty parameter set?
- [ ] Is the foundation layer at full branch coverage, and does every documented edge case have a test?

## Sources

See `sources.md`, entries Anthropic (*Best practices for Claude Code*); SQLite (*How SQLite Is Tested*, *The Use Of
assert() In SQLite*); WebKit (*Contributing Code*); Hugging Face (*How to add a model to Transformers*); PyTorch
(*torch.testing*); 15r10nk (*inline-snapshot*); Apple (*FoundationDB testing*, *swift-collections*); Zhou
(*FoundationDB*); Scientific Python (*Development Guide: pytest*); Mineault (*The Good Research Code Handbook:
testing*).
