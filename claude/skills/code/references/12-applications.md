# 12. Applications

An application follows the same principles as a library with a different promise: a reproducible result for its
owner instead of a stable API for strangers. Every knob lives in a TOML config, keyed by name, and the command line
takes only targets. Each run writes one run directory whose run manifest, written last, records exactly what ran,
and a resume trusts the run manifest, not the existence of a file. Raw data is read-only and reached through one
resolver, libraries are consumed through their public surface at pinned versions, and the implementation stays as
small as the result needs while the interfaces meet the library bar.

## Principles

### 12.1 Put every knob in a config file keyed by name, and let the command line take only targets [Law 2]
**Why.** A config file can be diffed, reviewed and embedded whole in the run manifest; flags in shell history cannot.
TOML is data that the standard library reads and that executes nothing. One loader reads every config: a file may
name a base, a key the base lacks is an error because a typo would otherwise run with the default, and each default
lives once, in the base file. Every table is keyed by name, never by position: a weight that differs per stage sits
in that stage's table, so adding a stage adds one table and edits no row. The command line says what to process
(inputs, output root, config path, selection), never how.

**Example.** Per-stage tables keyed by name (sketch):
```toml
[stages.kinematics]
rounds = 4
iters = 1000

[stages.kinematics.loss_weights]
pose = 1e3
root = 1e2

[stages.dynamics.loss_weights]
pose = 1e3
root = 1e2
```
`tracking/BetterRetarget/configs/retarget.toml` holds the same weights as positional columns, one entry per stage
(`pose = [1e3, 1e3]`), so adding a stage edits every row.

**Check.** A test loads a config with a misspelled key and expects an error. Review question: does any CLI option
change the result rather than the target?

### 12.2 Write each run into its own run directory, with a run manifest that records exactly what ran [Law 8]
**Why.** A number without its run is not a result, and a published number names its command and its run directory
(7.4). The run manifest is `manifest.json`, written last, in every directory that one invocation writes; it names
the format of that directory and its version (8.7). It records the command line; the resolved config, embedded
rather than named by path; the code commit and a dirty flag, with `git diff` saved as `code.diff` beside it when the
tree is dirty; the Python, torch and CUDA versions, the lockfile hash, and the version and commit of each consumed
library; the device; the inputs as paths relative to the data root with their checksums; the start and finish times;
and the status. The seed is a config key, set once at the entry point and passed down as generators (5.1).

**Example.**
```json
{
  "format": "betterretarget-run",
  "format_version": 1,
  "status": "complete",
  "started": "2026-10-25T16:43:02Z",
  "finished": "2026-10-25T17:10:45Z",
  "command": ["python", "-m", "betterretarget.retarget", "--clips", "amass_cmu_88_06"],
  "config": {"seed": 0, "stages": {"order": ["kinematics", "dynamics"]}},
  "code": {"commit": "161a182", "dirty": false},
  "environment": {"python": "<version>", "torch": "<version>", "cuda": "<version>", "uv_lock_sha256": "<hash>",
                  "libraries": {"better-robot": "0.2.0@d1da22a", "better-human": "0.1.0.dev0@6232cbe"}},
  "device": "<device name>",
  "inputs": {"inputs/amass_cmu_88_06/human.npz": "sha256:<hash>"}
}
```

**Check.** The smoke test (12.7) asserts every run manifest field. Review question: can this result be reproduced
from its run manifest alone?

### 12.3 Judge completion by the run manifest, and write outputs so that a crash or a rerun never leaves a mixed directory [Law 7]
**Why.** Jobs get preempted, users run a command twice, and agents retry, so every operation with side effects is
safe to repeat: the same inputs give the same output path, no duplicate entries and no half-written file. A file that
exists may be half written, or written under an older config. A stage writes into a staging directory and moves it
into place when it is done, run manifest last. A resume skips a step only when its run manifest says `complete` and
its config, code and input hashes match. Each output file has one producer: a stage never rewrites another stage's
output in place, because the file's meaning would then depend on history. Old outputs that a rerun replaces go to
the trash, never to deletion.

**Example.**
```python
def publish_stage(staging: Path, *, final: Path, trash: Path) -> None:
    """Move a finished stage directory into place; its run manifest was written last.

    A previous output moves to ``trash`` instead of being deleted, so a rerun is reversible.
    """
    if final.exists():
        final.rename(trash / f"{final.name}_{time.strftime('%Y%m%d-%H%M%S')}")
    staging.rename(final)
```

**Check.** A test runs a stage twice and compares the outputs. A test stops a smoke run in the middle of a stage,
resumes it, and compares the outputs with a clean run.

### 12.4 Treat raw data as read-only, write derived data to separate trees, and put no absolute path in a tracked file [Law 9]
**Why.** Raw data is the one input that cannot be regenerated. Conversions, labels and filters write separate files
beside their source, never over it. Every path in a tracked file is relative to a root from the resolver (9.3), and
every dataset root derives from the one data root. An absolute path in code, a config or a docstring breaks on every
other machine and whenever the repository moves. Notes and replies to the owner follow 10.5.

**Example.** Two absolute paths (`tracking/BetterRetarget/betterretarget/clips.py`, `human.py`):
```python
DATA_ROOT = Path("/home/rikhat.akizhanov/better/tracking/data")
SMPLX_DIR = Path("/home/rikhat.akizhanov/better/BetterHuman/models/smplx")
```

**Check.** A contract test fails when `git grep -nE '(^|[^[:alnum:]_.~/-])/(home|data[0-9]*)/' -- '*.py' '*.toml'
'*.md'` finds anything, in code, strings, comments and docs alike (example: `tests/contract/test_no_absolute_paths.py`).

### 12.5 Consume libraries only through their public surface, at pinned versions, and never copy what they provide [Law 5]
**Why.** A library's public surface is what it promises to keep (8.4); anything else may change in any commit, so an
application that reaches in breaks without warning. Data an application needs from a library ships as package data
and is reached through a library function; the layout of a checkout is not an interface. `pyproject.toml` pins each
library as 8.10 says: a release tag or version, and a commit rev until the library's first release; never a branch
or a path. To work against a local checkout, run each command as `uv run --with-editable <path> <command>`: the
checkout replaces the pinned library for that command only, `pyproject.toml`, the lockfile and the environment stay
untouched, and the run manifest records the checkout's commit and dirty flag. A helper two applications need, or
a workaround for a library defect, becomes a change to the library.

**Example.**
```toml
[tool.uv.sources]
better-robot = { git = "https://github.com/rihat99/BetterRobot", tag = "vX.Y.Z" }   # a release tag
better-human = { git = "https://github.com/rihat99/better_human", rev = "6232cbe0c19c52a90a9612c125726d348d126a11" }
```

**Check.** The application runs the consumer import test of 1.6 against every library it uses, and a test fails
when `[tool.uv.sources]` contains `branch =` or `path =`.

### 12.6 Lay out an application like a library, with one module per stage and one stage table [Law 2]
**Why.** The same tree means the same checks (9.1). A stage is a function of its inputs, its config section and its
seed. Its output files, with their keys, shapes and units, are listed in one stage table in the docs. The core
package never imports dataset adapters; the adapters are a second package that depends on the core, and an edge
table enforces the direction (1.1). One module builds the command of every stage, so two runners cannot drift.

**Example.**
```text
src/bvr/              core: stages/, runner.py, config.py, paths.py; never imports bvr_datasets
src/bvr_datasets/     one subpackage per dataset; imports bvr
configs/              base TOMLs, and one subfolder per dataset for its deltas
```

**Check.** An edge-table test covers the application's packages. Every module under `stages/` has a row in the stage
table.

### 12.7 Test the glue, not the research [Law 8]
**Why.** Research code changes by the hour, and the global rules exempt research and one-off scripts from tests
unless the owner asks. The glue changes rarely and breaks everything when it does: config loading, the stage table,
the runner, the resolver, the run manifest. A smoke run of the whole chain on a tiny input catches most glue
failures; it takes minutes, so it runs in the full tier. A regression parity compares the chain's output on one
fixed input with the last accepted run, within a stated tolerance, against a golden with recorded provenance (6.4).

**Example.**
```python
def test_chain_on_tiny_clip(tmp_path: Path) -> None:
    """The default chain runs end to end on a 10-frame clip, and every stage writes what its table lists."""
    run_dir = run_chain(TINY_CLIP, config=BASE_CONFIG, out_root=tmp_path)
    manifest = json.loads((run_dir / "manifest.json").read_text())
    assert manifest["status"] == "complete"
    for stage, keys in STAGE_OUTPUTS.items():
        with np.load(run_dir / stage / "result.npz") as result:
            assert keys <= set(result.files), stage
```

**Check.** CI runs the smoke test in the full tier on every push. A misspelled config key fails a test.

### 12.8 Keep the implementation as small as the result needs, and hold the interfaces to the library bar [Law 10]
**Why.** An application has one owner and one goal, so its implementation can give way first. Solve most of the
problem with little code, delete stages and dependencies that no longer run, and add machinery (adaptive schedules,
switching rules, special starts) only when it wins on every input and the owner agrees. The interfaces cannot give
way: file formats, config keys, the CLI and the output tree are read by other code and by the owner months later.
Prefer a method that needs no hand-tuned cutoffs to a method plus rules that patch its failures; among methods that
need none, the simplest wins.

**Example.** Each stage runs a fixed number of rounds of a fixed number of L-BFGS iterations; only the force solves
inside a round stop early, by a rule the config states beside them (`tracking/BetterRetarget/configs/retarget.toml`):
```toml
[stages.kinematics]
rounds = 4
iters = 1000
```

**Check.** Review questions: which part of this change could be deleted without changing the result on the
regression input? Does every dependency have an importer?

## Application profile

This chapter is the application profile in full. Each chapter's own application profile lists what that chapter
relaxes for an application; anything no profile lists is not relaxed.

Relaxed for a library:
- 12.1, 12.6, 12.7 and 12.8 apply to applications only.

Not relaxed for a library:
- 12.2 and 12.3 apply to its benchmark runs and golden generators, 12.4 to its assets, and 12.5 to the libraries it
  depends on.

## Checklist
- [ ] Does every knob live in a TOML config, keyed by name, read by one loader that rejects unknown keys?
- [ ] Does every run directory hold a run manifest, written last, with command, config, code, environment and inputs?
- [ ] Is every step safe to repeat, with resumes trusting only a complete run manifest whose hashes match?
- [ ] Is raw data read-only, derived data in separate trees, and every tracked file free of absolute paths?
- [ ] Are libraries consumed through their public surface, pinned as 8.10 says, with nothing copied from them?
- [ ] Is the application laid out like a library, with one module per stage and one stage table?
- [ ] Do the tests cover the glue: a smoke run in the full tier, the config loader, and each bug fixed in the glue?
- [ ] Is the implementation the smallest that gives the result, with the interfaces held to the library bar?

## Sources

See `sources.md`, entries DrivenData (*Cookiecutter Data Science*); Mineault (*The Good Research Code Handbook:
setup*, *testing*); ashleve (*lightning-hydra-template*); Papers with Code (*Releasing research code*); Karpathy
(*nanoGPT*); PyTorch (*Reproducibility*); Leach (*Designing robust and predictable APIs with idempotency*); Gabriel
(*The Rise of Worse is Better*); Ousterhout (*A Philosophy of Software Design*); Redis (*MANIFESTO*); Apple (*Human
Interface Guidelines*); Astral (*uv: project layout and lockfile*); Owner (*Global working rules*).
