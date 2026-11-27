# 5. State, determinism, performance

Every state is a pure function of the model and the input (1.4), so the same model and input on the same device,
build and versions give the same bits, and every other reproducibility claim names its scope. Randomness, dtype and
device belong to the caller: they arrive as arguments, a library sets no process-wide state, and nothing casts or
moves a tensor behind the caller's back. Hot paths never wait on the host, and the model fixes their structure while
only tensor values vary. Speed is measured before it is changed, across the whole working-set range, and gated by
counters that do not flake.

## Principles

### 5.1 Take randomness as a `generator` argument, and seed only at the program's entry point [Law 4]
**Why.** A global random stream makes a result depend on every draw made before it, in any library, in any order. A
`torch.Generator` passed in makes the stream part of the input, so a test or a run replays from its seed alone. A
function that has to draw and was given no generator raises; it never falls back to the global stream. Seeding,
determinism switches, default dtype and device, and thread counts belong to the program that owns the process.

**Example.** The ban is a lint whose message carries the fix (`BetterRobot/pyproject.toml`):
```toml
[tool.ruff.lint.flake8-tidy-imports.banned-api]
"torch.manual_seed".msg = "C-DEP-3: no process-wide RNG seeding inside the library; take a generator"
"torch.use_deterministic_algorithms".msg = "C-DEP-3: no process-wide torch settings inside the library"
```
`BetterRobot/src/better_robot/terms/ik.py::random_start` takes `generator: torch.Generator | None = None` and always
draws, so a call without a generator reads torch's global stream.

**Check.** The banned-api lint (ruff `TID251`) lists every process-wide setter. A test calls each sampling function
without a generator and expects an error. Review question: can this result change because of a random draw made
somewhere else?

### 5.2 State each reproducibility promise with its scope, and pin it with a test [Law 4]
**Why.** "Reproducible" without a scope cannot be tested, and PyTorch does not promise equal results across releases
or between CPU and GPU. Three scopes cover every case. Bitwise: the same model, input, device, build and versions
give identical bits run to run. Tolerance: across devices, dtypes and thread counts, results agree with the oracle
within a stated tolerance. None: across torch releases and platforms, unless a test says otherwise. A bitwise promise
rules out kernels that reduce in a nondeterministic order, such as atomic adds, so it is a decision written down with
its cost, and once tested and documented it is part of the public surface (8.4).

**Example.** A bitwise promise compares with `torch.equal`
(`BetterRobot/tests/collision/test_collision.py::test_cuda_backward_is_bitwise_reproducible`, abridged):
```python
for name, (fn, inputs) in cases.items():
    first, second = gradients(fn, inputs), gradients(fn, inputs)
    assert all(torch.equal(x, y) for x, y in zip(first, second)), name
```

**Check.** Review question: does every reproducibility claim in the docs name its scope and the test that pins it? A
bitwise test compares with `torch.equal`, never with a tolerance.

### 5.3 Never cast, move or promote a tensor silently [Law 7]
**Why.** The caller chose the dtype and the device. A silent cast hides a float32 computation behind a float64 oracle
comparison, and a silent `.to()` hides a host-device copy inside a hot path. The model fixes one dtype and one
device, and an input that disagrees raises at the boundary with a message that names both values and the fix.
Numerics that depend on precision, such as small-angle cutoffs, are chosen per dtype and say why.

**Example.** The boundary check names the mismatch and the fix
(`BetterRobot/src/better_robot/kinematics/state.py::_validate_q`):
```python
raise DtypeMismatchError(
    f"q.dtype={q.dtype} != model.dtype={model_dtype}. Cast q or call model.to(dtype=q.dtype) before evaluation."
)
```
`BetterRobot/src/better_robot/data_model/model_structure.py::ModelStructure.integrate` breaks the rule: it promotes a
float32 `q` with a float64 `v` to float64 without a word.

**Check.** A contract test calls every public entry point in float32 and float64 and asserts the output dtype and
device (example: `tests/contract/test_dtype_device.py`), and one mixed-dtype call per entry point must raise. Review
question: does any `.to(`, `.float()`, `.double()` or `promote_types` touch an input tensor?

### 5.4 Keep hot paths free of host synchronisation [Law 7]
**Why.** `.item()`, `.cpu()`, `.numpy()`, `float(t)`, `bool(t)` and `if t:` make the host wait for the GPU queue to
drain, and they break `torch.func` tracing and full-graph compilation. A hot path is the per-call code of the math
layers and the solver step; once-per-model setup is not. Decisions that depend on values stay on the device as masks
and `torch.where`. Some torch calls synchronise without looking like it (`torch.nonzero`, boolean-mask indexing), so
a static lint is paired with a runtime count. An exception is marked on its own line with its reason.

**Example.** How the solver's agent file could state it (sketch for `BetterRobot/src/better_robot/optim/CLAUDE.md`):
```python
# good: one mask, stays on the device
converged = step_norm < tolerance                    # (B,)
x = torch.where(converged[:, None], x, x + step)     # (B, n)
# bad: drains the queue on every iteration
if step_norm.max().item() < tolerance:
    break
```

**Check.** An AST lint over the hot-path packages fails with a message that names the escape
(`# bench-ok: <reason>`), and the host-sync counters of 5.8 run in the GPU job (9.5).

### 5.5 Let the model fix the structure of a computation, and let only tensor values vary [Law 4]
**Why.** When Python control flow, loop counts and shapes depend only on the model's static structure, one traced
graph serves every input: `torch.compile` traces it once, `vmap` batches it, and the cost is predictable. Loop over
structural axes (joints, iterations) whose length is a Python int fixed by the model, never over batch elements, and
branch on values with `torch.where`. The static structure compares and hashes by value, so it can key a cache or be a
compile-time constant.

**Example.** The batch rule (`BetterRobot/docs/contracts/09-performance.md`, C-PERF-2):
```python
# good
for joint in model.joints:                 # structural, len = model.njoints
    X_WB = X_WB @ joint_placement(joint, q[..., joint.idx_q])   # batched over `...`
# bad
for b in range(q.shape[0]): ...
```

**Check.** A `fullgraph=True` compile test per public hot path, and a test that equal structures hash equal. Review
question: does any Python `if` or loop bound depend on a tensor value?

### 5.6 Profile before changing code for speed, and land every optimization with its numbers [Law 8]
**Why.** The global rules say to profile first; this rule says what the change must show. An optimization states the
benchmark command, the machine, the numbers before and after, and which invariants still hold. An optimization
without a measured win is code without a reason, and it is removed. A second backend, a custom kernel, a compile
wrapper or a cache is maintained forever, so each one starts as a decision record (11.6) that records the losing
measurements too, and the choice can be reopened on evidence instead of opinion.

**Example.** The single-backend decision rests on numbers in both directions
(`BetterRobot/docs/contracts/decisions/0001-torch-only.md`): at batch 4096 on one CPU, Warp won forward-only FK
(2.3 ms vs 6.6 ms on the Panda) and lost with gradients (106 ms vs 23 ms); at batch 1 torch won both. A second
backend doubled every test and every contract, so the Warp lanes went.

**Check.** The change description carries a `Benchmark:` line with command, machine, before and after. Review
question: which measurement would show that this optimization is no longer needed?

### 5.7 Benchmark each hot entry point across its whole working-set range, beside its oracle [Law 8]
**Why.** One batch size hides crossovers: the Warp lanes above won at batch 4096 and lost at batch 1. Sweep the batch
over powers of two from 1 to 65536 and the model from a few joints to the largest supported, and plot time per
element on log-log axes, one plot per operation. Run the oracle of the parity tests in the same harness with matched
dtype, device and thread count, so the comparison is like for like.

**Example.** A sweep as parametrized benchmarks (sketch):
```python
BATCH_SIZES = [2**k for k in range(17)]                       # 1 .. 65536
MODELS = ["pendulum", "panda", "g1_free_flyer"]
IMPLEMENTATIONS = {"better_robot": fk_better_robot, "pinocchio": fk_pinocchio}


@pytest.mark.bench
@pytest.mark.parametrize("implementation", IMPLEMENTATIONS)
@pytest.mark.parametrize("model_name", MODELS)
@pytest.mark.parametrize("batch", BATCH_SIZES)
def bench_forward_kinematics(benchmark: BenchmarkFixture, *, batch: int, model_name: str, implementation: str) -> None:
    """Time one FK call on q: (batch, nq), float64, one thread."""
```

**Check.** Review question: does the sweep include batch 1 and the largest batch, and an oracle row at the same
dtype, device and thread count? The plot script reads the benchmark output; nobody copies numbers by hand.

### 5.8 Gate performance on deterministic counters, and explain every wall-time regression in writing [Law 8]
**Why.** Wall time varies between machines and runs, so a wall-time gate either flakes or is set so loose that it
catches nothing, and an advisory benchmark that nobody compares catches nothing at all. Counters do not flake for a
given torch version and device. The counters that run on CPU (graph breaks, recompiles, allocations) gate every
push. The CUDA counters (host syncs, kernel launches, peak memory) run in a GPU job when the project has one (9.5).
Their thresholds are data in `benchmarks/`, one file per torch version, changed only in a commit of their own (11.7).
Wall time is recorded on one named reference machine, and a slowdown past the project's stated threshold lands only
with a written reason, so "simpler but slower" is a decision and never an accident.

**Example.** A CPU counter test against its threshold (sketch):
```python
THRESHOLDS = json.loads((ROOT / "benchmarks" / "thresholds" / f"torch-{TORCH_VERSION}.json").read_text())


def test_forward_kinematics_compiles_without_graph_breaks(panda: Model) -> None:
    q = panda.q_neutral.expand(1024, -1).clone()                                  # (1024, nq)
    explanation = torch._dynamo.explain(forward_kinematics_state)(panda, q)
    assert explanation.graph_break_count <= THRESHOLDS["forward_kinematics_state/panda/B1024"]["graph_breaks"]
```
`BetterRobot/tests/bench/README.md` calls its benchmarks advisory: a manual job records numbers and compares nothing.

**Check.** CI runs the CPU counter tests on every push and the CUDA counter tests in the GPU job. A change that
touches a hot path reports the wall-time delta from the reference machine.

## Application profile

Relaxed:
- An application may set process-wide state, but only in its entry point: seed once, switch on deterministic
  algorithms, choose the device, all driven by its config.
- Counter gates cover only the application's own hot loops, and the working-set sweep (5.7) is optional.

Not relaxed:
- Each stage is a pure function of its inputs, its config and its seed, and the run manifest records seed, versions
  and device (12.2).
- No stage boundary changes dtype or device silently (5.3).
- Every determinism claim names its scope and the run that measured it (5.2).

## Checklist
- [ ] Does every random draw come from a `generator` argument, with an error when none is given?
- [ ] Does every reproducibility claim name its scope (bitwise, tolerance, none) and the test that pins it?
- [ ] Does every public entry point preserve dtype and device, and raise on a mismatch with the fix in the message?
- [ ] Is the hot path free of host syncs, with each exemption marked with its reason on its own line?
- [ ] Do loop bounds and branches depend only on static structure, and does the structure hash by value?
- [ ] Does each optimization carry its benchmark command, machine and numbers, and each costly mechanism a record?
- [ ] Does each hot entry point have a sweep from batch 1 to the largest batch, beside its oracle?
- [ ] Do the CPU counters gate every push, and does every wall-time regression past the threshold have a reason?

## Sources

See `sources.md`, entries JAX authors (*Stateful computations*, *Pseudorandom numbers*); PyTorch (*Reproducibility*,
*torch.func UX limitations*, *Design Philosophy*); DeepMind (*MuJoCo documentation*); Carpentier (*The Pinocchio
C++ library*); Mineault (*The Good Research Code Handbook: testing*); Apple (*swift-nio*); WebKit (*Performance*,
*Project Goals*); Swift.org (*Introducing Swift Collections*); McKinley (*Choose Boring Technology*); Fitzpatrick
and Crawshaw (*An unlikely database migration*).
