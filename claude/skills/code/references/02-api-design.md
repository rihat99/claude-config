# 2. API design

Design an API from its call site: write the example call and the one-sentence doc comment first, and change the
design if either is hard to write. Give each task one path and each datum one access path, use defaults instead of
method families, and keep only the subject and the main operand positional. Disclose depth in levels, each reached
by an explicit step, and publish the facts that cut across functions as a table backed by tests. Classify failures by
how the caller should react, validate structure once at the boundary, and keep every promise a type makes.

## Principles

### 2.1 Design from the call site, and write the one-sentence doc comment before the code [Law 1]
**Why.** A declaration is read once; a call is read every time. A signature judged alone hides what the caller has
to write around it. The doc comment is a design test: a function that cannot be described in one plain sentence does
too much, or the wrong thing. A line that every caller writes is a missing default or a missing function.

**Example.** The README, the getting-started pages and the examples all write this line, because the Panda's neutral
configuration lies outside its joint limits (`BetterRobot/README.md`):
```python
q0 = model.q_neutral.clamp(model.lower_pos_limit, model.upper_pos_limit).expand(64, -1)
```
When every caller writes the same line, the library owns it.

**Check.** Every public docstring opens with one sentence. A design review starts from the example call, before the
implementation exists. Review question: what does every caller write around this call? Search the docs and examples
for repeated lines.

### 2.2 Give each task one path and each datum one access path [Law 2]
**Why.** Two ways to do one thing double what readers learn, what docs explain and what tests cover, and an agent
copies whichever it saw first. Forwarding properties give every datum two names, so a composite either exposes its
parts or forwards their fields, never both. The composite is the default, because callers think in terms of the
whole, and its parts then leave the public surface. Expose the parts instead, with no forwarding, only when callers
pass, store or transform a part on its own. If the split exists only so that `torch.func` can tell static fields
from tensor fields, keep one composite, mark each field's kind on it, and let a function split it when needed.

**Example.** One library, two spellings of each task:
```text
model.fk(q)                    forward_kinematics_state(model, q)
result["q"]                    result.x["q"]
load(path, free_flyer=True)    load(path, root_joint=JointFreeFlyer())
model.nq                       model.structure.nq
```
Callers read through the composite almost everywhere and replace values through `model.with_values(...)`, so
`Model` is the path, and `ModelStructure` and `ModelValues` leave the public surface
(`BetterRobot/src/better_robot/data_model/model.py::Model`).

**Check.** A docs test fails on each listed alternate spelling. Review question: is there already a way to do this?
If so, the change removes one of the two.

### 2.3 Prefer defaults to method families, and make every parameter after the subject and main operand keyword-only [Law 1]
**Why.** A method family makes readers learn several names for one operation and makes docs explain each. A default
argument costs one line of documentation. Keyword-only parameters let a signature grow without breaking calls and
make a call site readable without the signature. A positional boolean is unreadable. Forwarding `**kwargs` hides the
real signature from readers, type checkers and agents. Every default has a written reason.

**Example.** Subject and main operand positional, the rest keyword-only, and the docstring gives the reason for the
defaults: "both are off by default so a reachable target is reached exactly"
(`BetterRobot/src/better_robot/terms/ik.py::ik_problem`):
```python
def ik_problem(
    model: Model,
    targets: Mapping[str, torch.Tensor],
    *,
    q0: torch.Tensor,
    limit_weight: float = 0.0,
    rest_weight: float = 0.0,
    q_rest: torch.Tensor | None = None,
) -> Problem:
```

**Check.** A contract test allows at most two positional parameters per public callable, with a ratchet for known
violations (example: `tests/contract/test_keyword_only.py`); ruff `FBT001`, `FBT002` and `B006` hold; review rejects
`**kwargs` in a public signature. Review question: why does this default have this value, and where is that written?

### 2.4 Disclose depth in levels: the first level needs no advanced concept, and each deeper level is an explicit step [Law 3]
**Why.** A beginner finishes the common task without meeting the machinery under it. An expert reaches that
machinery without leaving the library or copying its internals. Levels that build on each other, each reached by one
explicit step, serve both, and the docs present them in the same order. A level is a depth of disclosure; a layer is
a rank in the import graph (1.1).

**Example.** Four levels of one capability, each imported through its canonical path (1.6): `solve_ik` is a
first-level name, so it comes from the root (sketch over `BetterRobot/src/better_robot/terms/ik.py` and
`BetterRobot/src/better_robot/optim/phases.py`):
```python
import better_robot
from better_robot import optim, terms
from better_robot.optim import LevenbergMarquardt, Phase

result = better_robot.solve_ik(model, targets, q0=q0)                          # 1. recipe, a first-level name
problem = terms.ik_problem(model, targets, q0=q0, rest_weight=0.1)             # 2. open recipe, add terms
result = optim.run(problem, [Phase(solver=LevenbergMarquardt(), iters=50)])    # 3. phases
result = optim.solve_layer(problem, LevenbergMarquardt(), iters=50)            # 4. differentiable in the data
```

**Check.** The getting-started page uses only level 1, and each level's page links to the next. Review question:
which level does this addition belong to, and does a beginner now meet it?

### 2.5 Let a flag change what a function promises and pin its cost; never let it pick between two implementations [Law 2]
**Why.** A flag that selects an algorithm doubles the code and the tests, and leaves the reader to guess which choice
is right. If two implementations keep the same promise, delete the worse one. A flag earns its place when it trades
something the caller can name, such as accuracy for speed, and a test pins the price.

**Example.** A flag keeps a second sort alive to preserve a historical default
(`BetterRobot/src/better_robot/io/build_model.py::build_model`, condensed):
```python
    if preserve_joint_order:
        sorted_ir_indices = _ir_stable_topo_sort(ir, root_body, regular_ir_indices)
    else:
        sorted_ir_indices = _ir_topo_sort(ir, root_body, regular_ir_indices)
```
Both orders keep the promise that parents precede children, so one of them goes. By contrast, BetterHuman's
`stream_joints=False` trades joint accuracy for speed, and
`BetterHuman/tests/parity/test_smplx_parity.py::test_smplx_static_joints_are_approximate` holds the error in a band.

**Check.** Every flag's docstring names what it trades, and a test pins the cost of each non-default value. Review
question: if this flag were deleted, what would a caller lose? "The old behaviour" is not an answer.

### 2.6 Publish one effects table for the public API, and back every cell with a test [Law 8]
**Why.** Users and agents need facts that cut across functions: autograd, `torch.func`, `torch.compile`, host
syncs, input mutation, dtypes and devices. Scattered across contract pages and changelog lines, these facts drift.
Generated from the contract tests, the table cannot lie: each cell is a test result or blank.

**Example.** The contract tests iterate one registry of public entry points
(`BetterRobot/tests/contract/_public_ops.py`, used by `test_no_inplace.py` and `test_dtype_device.py`). The table
renders their results, one row per entry point:
```text
| Function | autograd | vmap | compile fullgraph | no host sync | inputs untouched | float32, float64 | CPU, CUDA |
```

**Check.** The docs build regenerates the table from a test run and fails on a cell with no test behind it. Review
question: which column does this change affect, and did the table change with it?

### 2.7 Classify every failure by how the caller should react, and test every edge case the docstring names [Law 7]
**Why.** One mechanism for everything makes callers over-catch or under-handle. A caller's bug stops at the boundary
with a message that names what arrived, what was expected and the fix. A domain outcome is data in the result. An
environment failure is a specific exception the caller can catch, from one tree rooted at the library's base error.
A legal edge case is defined out of existence: an empty batch flows like any batch, and `difference(q, q)` is exactly
zero. That is not a silent fallback: malformed input still raises, nothing is swallowed, and each edge case a
docstring names (angles at 0 and near pi, an empty batch, `nq != nv`, a missing file) has a test that reaches it.

**Example.** The three classes in one library (`BetterRobot/src/better_robot/exceptions.py`,
`BetterRobot/src/better_robot/optim/phases.py::Result`):

| Failure | Case | Mechanism |
|---|---|---|
| caller's bug | `q.dtype` differs from the model's | `DtypeMismatchError` at the boundary, the fix in its message |
| domain outcome | a solve that did not converge | data in the result: `Result.done`, `(B,)` |
| environment | an optional dependency is absent | `BackendNotAvailableError`, an `ImportError` with an install hint |

Anti-example: `BetterRobot/src/better_robot/viewer/robot.py` catches every exception of the mesh loader and returns
`None`, so a mesh vanishes from the scene without a word.

**Check.** Every public docstring says what raises. Ruff `BLE001` and `E722` hold in library source, except where a
boundary re-raises with context. A defined-away case is tested for its value and for a finite gradient. Review
question: how should the caller react to this failure, and does the mechanism match?

### 2.8 Validate in a fixed order: types, structure once at the boundary, opt-in value checks, named unchecked passes [Law 7]
**Why.** Each rung has its cost and its place. Types catch mistakes before anything runs. Structural checks (shape,
dtype, device, model attachment, name resolution) run once in the public wrapper, and everything below trusts them.
A check that reads tensor values syncs the host and breaks `vmap`, so it hides behind a keyword flag that defaults to
off. A trusted internal pass carries a name that says so, so a reader knows which side of the boundary a function is
on.

**Example.** One boundary, one opt-in value check, with its cost stated
(`BetterRobot/src/better_robot/kinematics/state.py::forward_kinematics_state`):
```python
def forward_kinematics_state(model: Model, q: torch.Tensor, *, check_quaternion_norm: bool = False) -> KinematicState:
    """Forward kinematics. ``q: (B..., nq)`` → `KinematicState` of joints and frames.

    ``check_quaternion_norm=True`` raises `QuaternionNormError` when a free-flyer
    quaternion is far from unit norm. It syncs accelerators, so it is off by default.
    """
```
Unchecked passes end in `_raw`
(`BetterRobot/src/better_robot/kinematics/jacobian.py::frame_jacobian_time_variation_raw`) or live in a private
module.

**Check.** A contract test asserts exactly one validation call per public entry point (example:
`tests/contract/test_boundary_validation_count.py`), and the hot-path lint forbids value reads below the boundary.
Review question: which rung does this check sit on?

### 2.9 Keep every promise a type makes: each adopted protocol in full, and value behaviour if it claims to be a value [Law 5]
**Why.** Adopting a protocol (`__eq__`, `Mapping`, `nn.Module`, a family API) promises every documented behaviour of
it. Generic code trusts the whole promise, so a type that keeps half of it breaks code far away. Approximate equality
is not `__eq__`, and configurations are not added with `+`. A frozen dataclass of tensors is a value only if no
caller can change it in place through a returned tensor. A type that cannot keep the promise offers an adapter or a
view instead.

**Example.** The family contract promises one body API (H-API-1, `BetterHuman/docs/contracts/bh-addendum.md`), and
the converters take and return different things (`BetterHuman/src/better_human/families/classic.py`, `mhr.py`,
`soma.py`):
```python
def smpl_from_classic(identity: Identity, classic: SMPLClassic) -> tuple[torch.Tensor, Stream]: ...
def mhr_from_classic(body: Body, classic: MHRClassic) -> tuple[Identity, torch.Tensor, dict[str, torch.Tensor]]: ...
def smpl_to_classic(identity: Identity, q: torch.Tensor, stream: Stream | None = None) -> SMPLClassic: ...
def soma_to_classic(identity: Identity, q: torch.Tensor) -> SOMAClassic: ...
```

**Check.** Each protocol has one property checker that runs against every implementation (6.7), and each family API
has one signature test across its members. Review question: which documented behaviour of this protocol does the
type not keep?

## Application profile

The public surface of an application is its command line, its config keys, its output files and its output tree
(8.4).

Relaxed:
- 2.7 and 2.8 apply to that surface only. Python functions inside the application are internal, need no effects
  table (2.6), and are reviewed under the internal bar (11.1).
- 2.4 asks for one documented entry command per task, not a layered API.

Not relaxed:
- One way to set each knob: in the config, never on the command line (12.1).
- Failures classified by reaction (2.7): a frame with no detection is data, a config error stops before any compute.
- Validation at the entry point (2.8).

## Checklist
- [ ] Was the example call written first, and does the doc comment open with one plain sentence?
- [ ] Does each task have one path and each datum one access path, with no forwarding mirror of public parts?
- [ ] Are defaults used instead of method families, with only subject and main operand positional and no `**kwargs`?
- [ ] Does the first level avoid every advanced concept, and is each deeper level an explicit step?
- [ ] Does every flag change what the function promises, state what it trades, and have its cost pinned by a test?
- [ ] Is every cell of the effects table backed by a test?
- [ ] Is each failure modelled by the caller's reaction, with nothing swallowed and every named edge case tested?
- [ ] Is structure validated exactly once at the boundary, value checks opt-in, and unchecked passes named as such?
- [ ] Does every adopted protocol and every claimed value behaviour hold in full?

## Sources

See `sources.md`, entries Swift project (*API Design Guidelines*, *Error Handling Rationale and Proposal*, *Swift
Evolution*); Apple (*swift-async-algorithms*, *swift-collections*, *swift-numerics*, *WWDC sessions*); Ousterhout
(*A Philosophy of Software Design*); Rust project (*Rust API Guidelines*); Python (*PEP 20*); WebKit (*Code Style
Guidelines*).
