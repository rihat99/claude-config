# 1. Architecture

Build a system as layers whose imports follow one edge table, checked by a test that sees every import. Make each
module deep, and let the parts combine through one coupling standard of shapes, layouts and file formats that
changes only by addition. Keep the model, the input and the state apart, compute each state as a pure function of
the other two, and declare every cache as a field. Hide hard numerics behind the plain signature with the plain path
as their oracle, and ship a deterministic stand-in for every backend that touches the outside world.

## Principles

### 1.1 Write the layer graph once, as an edge table in a test that sees every import [Law 2]
**Why.** A layer graph drawn in three documents drifts into three graphs. A rank table cannot say "dynamics may
import kinematics, not the reverse" when both share a rank, so the real graph lives nowhere. A test that reads only
module-level imports passes an upward edge hidden inside a function. An edge table is policy: each allowed edge is
listed, every other edge is forbidden, and adding one is a reviewed decision.

**Example.** The edges are data, and the test walks the whole syntax tree
(`BetterHuman/tests/contract/test_layer_dependencies.py`):
```python
ALLOWED: dict[str, set[str]] = {
    "core": set(),
    "io": set(),
    "families": {"core", "io"},
    "terms": {"core"},
    "viz": {ROOT, "core", "families", "io", "terms"},
    ROOT: {ROOT, "core", "families", "io", "terms"},
}
...
    for node in ast.walk(ast.parse(path.read_text())):
```
A test that scans only `tree.body` lets a lower layer import a higher one inside a method, as
`BetterRobot/src/better_robot/data_model/model.py::Model.fk` does. A convenience that needs a higher layer belongs
to that layer, or it goes.

**Check.** The layer test fails on an unlisted package or an unlisted edge, and it counts every import, inside
functions and under `TYPE_CHECKING` too. Every drawing of the graph (docs, agent file, package docstring) is
generated from the table or tested against it (7.7). Review question: does this change add an edge? Then a
decision record covers it (11.6), and the edge lands in a commit of its own (11.7).

### 1.2 Make each module deep: a small interface that removes a lot of knowledge from its callers [Law 3]
**Why.** Complexity is what a reader must hold in mind. A deep module replaces reading an implementation with
learning a short interface. A shallow module adds interface without hiding anything, so it costs more than it saves.
Named red flags turn the common failures into one word each, which makes review fast and lets an agent apply them by
rote.

**Example.** `better_robot.optim` hides normal equations, banded and arrow solvers, robust kernels and phase
scheduling behind one idea: a term is a plain function whose parameter names are the tensors it reads
(`BetterRobot/src/better_robot/optim/__init__.py`, module docstring):
```python
problem = Problem({"x": torch.zeros(4, 2)}, data={"target": torch.randn(4, 2)})
problem.residual("fit", lambda x, target: x - target)
result = solve(problem, LevenbergMarquardt(), iters=20)  # result.x["x"]: (4, 2)
```

**Check.** Review questions: what does this interface let its callers stop knowing, and which red flag does it
raise? A module whose public functions each forward to one other module is merged into it.

| Red flag | Sign |
|---|---|
| Shallow module | the interface is about as long as the implementation |
| Pass-through method | a method only calls a same-named method of the object it wraps |
| Information leakage | one design decision (a pose layout, a joint order) is known by several modules |
| Temporal decomposition | modules split by execution order (load, then fit) instead of by what they hide |
| Overexposure | a common call forces the caller to learn a rare feature |
| Conjoined methods | understanding one function requires reading another |

### 1.3 Define one coupling standard of shapes, layouts and file formats, and change it only by addition [Law 5]
**Why.** The coupling standard is the small set of conventions that every part reads: the configuration and tangent
shapes, the pose layout, frame identifiers, the file formats. It holds no Python function names; a function is
renamed through the deprecation path (8.9) like any public name. A brick from one decade fits a brick from the next
because the stud never changed. Kept compatible, the standard makes every added part more valuable, because it
attaches to every part already there. A convention that consumers need is public in the layer that owns it;
restated by hand in a second module, it splits into two copies that can disagree without a test noticing.

**Example.** The standard fits on one page (from `BetterRobot/CLAUDE.md`, "Numerical contracts", and
`BetterRobot/docs/contracts/05-api-shape.md`, C-API-4):
```text
q       (B..., nq)   configuration; nq may differ from nv
v       (B..., nv)   tangent; combined with integrate/difference, never with q + v
pose    (..., 7)     [tx, ty, tz, qx, qy, qz, qw], scalar last
twist   (..., 6)     [linear(3), angular(3)]
frame   int | str at every public boundary
```
`BetterHuman/src/better_human/viz/studio/layers.py::_quat_matrix` restates the quaternion convention by hand,
because the library's helper is private.

**Check.** Each consuming repository runs a coupling test (layouts, axis order, identifiers) against the standard.
Review question: does this change remove, rename or reorder anything in the standard? If so, it needs a decision
record (11.6), not a refactor.

### 1.4 Keep the model, the input and the state apart, and compute each state as a pure function of the other two [Law 4]
**Why.** The three have different lifetimes. The model is built once and never changes. The input (a configuration,
a velocity, a generator) arrives with each call. The state is derived from the model and the input and from nothing
else: no module global, no attribute an earlier call wrote, no hidden mode. Mixed in one mutable object they give
stale reads, autograd hazards and call-order coupling. Kept apart, `torch.func`, `torch.compile` and caching are
legal, and reproducibility becomes a sentence a test can check, in the scope 5.2 names.

**Example.** Each field of a state says what kind it is (`BetterHuman/src/better_human/core/body.py::HumanState`):

| Field | Kind |
|---|---|
| `identity` | reference to the model |
| `q`, `stream` | input |
| `model`, `kinematics`, `rest_joints`, `pelvis`, `rest_offset` | derived from the model and the input |
| `_memo` | declared cache (1.5) |

**Check.** A contract test calls every public entry point and asserts that each input tensor's `_version` counter
is unchanged (example: `tests/contract/test_no_inplace.py`). Every state type documents its field table. Review
questions: does this function read anything that is not an argument? Can this object be observed half-built, or
change after another object has read it?

### 1.5 Declare every cache as a field, written by one memo function next to it [Law 4]
**Why.** A cache that appears as an undeclared attribute escapes `repr`, equality and copying, and no reader finds it
by reading the class. The field is `field(default_factory=dict, init=False, repr=False, compare=False)`:
`init=False` makes `dataclasses.replace` start an empty memo, where a shared one would serve a value computed from
the replaced field. One memo function next to the field writes it, keyed by every hidden input the value depends on,
such as the grad mode. A write from another module couples two layers through a side door. A cache changes cost,
never a result.

**Example.** The field, its reason and its one writer (`BetterHuman/src/better_human/core/body.py::HumanState`):
```python
    # init=False: dataclasses.replace (e.g. a new identity) starts a fresh memo instead of sharing the old one.
    _memo: dict[str, torch.Tensor] = field(default_factory=dict, init=False, repr=False, compare=False)

    def _memoised(self, key: str, compute: Callable[[], torch.Tensor]) -> torch.Tensor:
        # A value computed under no_grad must not serve a grad-enabled caller: key by grad mode.
        key = f"{key}/{torch.is_grad_enabled()}"
```
Anti-example: `BetterRobot/src/better_robot/dynamics/state.py` writes `state._memo["world_geometry"]` into a
`KinematicState` from another package, and `KinematicState._memo` lacks `init=False`, so a state made with
`dataclasses.replace` returns the old `frame_pose`.

**Check.** A contract test builds each type that has a memo, reads every memoised property, replaces an input field
with `dataclasses.replace`, and asserts that each property recomputes. A lint fails on a write to a memo field
outside its memo function. Review question: if this cache were deleted, would any result change? It must not.

### 1.6 Make each package's `__all__` its public surface, and hold every consumer to it [Law 5]
**Why.** A consumer that imports an internal module couples itself to a layout nobody promised. `__all__` is the one
place that says what a package promises, and a dotted path is public when each of its segments is listed in its parent's
`__all__`: `pkg.sub.Name` needs `sub` in `pkg.__all__` and `Name` in `pkg.sub.__all__` (8.4 defines the public surface).
The root's `__all__` lists its subpackages and the first-level names (2.4), and nothing else. Each public name has one
canonical import path: the root for a first-level name, otherwise the package whose `__all__` lists it. A subpackage may
list a first-level name as well, but docs and consumers use the root path, because two paths give two spellings across
docs, examples and agent output. Fine-grained subpackages keep each job findable, and a consumer import test built from
each library's `__all__` holds every consumer to that surface.

**Example.** The import test each consumer runs (sketch):
```python
def _unlisted_segment(path: str) -> str | None:
    """A description of the first segment of a dotted path that its parent's ``__all__`` lacks, or None."""
    parts = path.split(".")
    for depth in range(1, len(parts)):
        parent = importlib.import_module(".".join(parts[:depth]))
        if parts[depth] not in vars(parent).get("__all__", ()):
            return f"{parts[depth]!r} is not in {parent.__name__}.__all__"
    return None


def test_imports_stay_on_the_public_surface() -> None:
    """Every segment of every path imported from a library is listed in its parent's ``__all__``."""
    imported = []
    for module in sorted(Path("src").rglob("*.py")):
        for node in ast.walk(ast.parse(module.read_text())):
            if isinstance(node, ast.Import):
                imported += [(module, alias.name) for alias in node.names]
            elif isinstance(node, ast.ImportFrom) and node.level == 0:
                imported += [(module, f"{node.module}.{alias.name}") for alias in node.names]
    leaks = [
        f"{module}: {path}: {reason}"
        for module, path in imported
        if path.split(".")[0] in LIBRARIES and (reason := _unlisted_segment(path))
    ]
    assert not leaks, "import through a path whose every segment is in its parent's __all__:\n" + "\n".join(leaks)
```
Run on `tracking/BetterRetarget/betterretarget/`, it reports the imports from `better_robot.kinematics.state`,
although `better_robot.kinematics` exports the same names, and from `better_human.core.pipeline`, which no
`__all__` lists. It also reports every other `better_robot` subpackage import, because that root's `__all__` lists
no subpackage.

**Check.** Every consumer repository runs the import test against each library it uses, over `import` and
`from ... import` alike. A docs test fails when a snippet imports a public name through a path other than its
canonical one. Review question: which `__all__` lists each segment of this path?

### 1.7 Keep specialised dependencies out of the core, and import each one at one boundary [Law 10]
**Why.** Every dependency of the core is paid by every user in install size, import time and breakage. A viewer, a
mesh loader or a file-format parser serves some users. It lives in its own subpackage, is imported where it is first
needed, and raises an install hint when it is missing. The import graph then says which feature needs what. A
dependency so specialised that it pulls a heavy stack belongs in a separate package.

**Example.** A test names, for each optional dependency, the only modules allowed to import it
(`BetterRobot/tests/contract/test_optional_imports.py`):
```python
RESTRICTED_OPTIONAL = {
    "yourdfpy": ("io/parsers/urdf.py",),
    "mujoco": ("io/parsers/mjcf.py",),
    "trimesh": ("io/parsers/", "viewer/", "collision/"),
    "viser": ("viewer/",),
```

**Check.** The boundary test, plus an import of the package with every optional extra absent. Review question: does
every user need this dependency? If not, which subpackage owns it?

### 1.8 Give every capability that touches the outside world an interface, a real backend and a shipped stand-in [Law 8]
**Why.** Code tested only against a real server, camera or device is slow and flaky to test. A stand-in is a
deterministic replacement that implements the same interface, runs without the outside world and records every
call, so tests are fast and exact. Shipped in the library's public surface, it lets every downstream project test the
same way. Kept as a private test helper, it gets copied, and the copies drift.

**Example.** A recording stand-in for the viewer's server runs the viewer tests and every docs snippet that opens a
viewer (`BetterRobot/tests/viewer/fake_server.py`):
```python
"""A recording stand-in for ``viser.ViserServer``: no sockets, every call and property write logged."""
```
Because it is a test helper, the downstream library keeps a copy (`BetterHuman/tests/viz/fake_server.py`), and the
two files differ. Shipped as a public module such as `better_robot.viewer.testing`, one file serves both.

**Check.** Each backend-facing interface has a stand-in in a public module of the library, and the library's own docs
test uses it. Review question: can a downstream project test this feature without the real backend and without
copying a file?

### 1.9 Hide hard numerics behind the plain signature, with the plain path as their oracle [Law 3]
**Why.** Tricky code is sometimes necessary: a batched kinematics formulation, an analytic derivative, a custom
kernel. Each one is maintained forever, so it lands only where a measurement demands it (5.6), and behind the same
signature as the plain path, so callers never choose. The plain path stays as its oracle, the independent reference
its parity test compares against, and the fast path lands only when it matches. A design note at the top of the
module is required where behaviour is not obvious from the code and encouraged elsewhere (7.6).

**Example.** An analytic Jacobian is one optional argument on the same term, and autodiff checks it (sketch over
`BetterRobot/src/better_robot/optim/problem.py::Problem.residual` and `::check_jacobian`):
```python
problem.residual("pose", pose_error)                        # plain path: the Jacobian comes from autodiff
problem.residual("pose", pose_error, jac=pose_error_jac)   # fast path: same term, one more argument
assert check_jacobian(problem)["pose"] < TOLERANCE          # the plain path is the oracle
```

**Check.** Each fast path has a parity test against the plain path whose docstring names its oracle. Review
question: does the caller need to know that this path is clever? The answer must be no.

## Application profile

Relaxed:
- The coupling standard (1.3) of an application is its config keys and its output tree. It may change between
  studies, if every run manifest records the format version of its run directory (8.7).
- The stand-in (1.8) may stay a private test helper, because no downstream project imports it.
- Stage code may stay shallow (1.2) while a method is exploratory, if each stage's inputs and outputs are listed in
  the stage table (12.6).

Not relaxed:
- The layer test (1.1): stages and library adapters are layers.
- The consumer import test against every library (1.6), declared caches (1.5), and the separation of config, inputs
  and outputs (1.4).

## Checklist
- [ ] Is the import graph an edge table in a test that sees every import, and is every drawing generated from it?
- [ ] Does each module let its callers stop knowing something, without raising a named red flag?
- [ ] Does the change leave the coupling standard intact, or does a decision record cover it?
- [ ] Are model, input and state separate, with each state's fields classified and no hidden input read?
- [ ] Is every cache a declared `init=False` field, written only by its memo function?
- [ ] Is every segment of every imported path in its parent's `__all__`, checked by the consumer import test?
- [ ] Is every specialised dependency imported only at its boundary, with an install hint?
- [ ] Does each backend-facing feature ship a deterministic stand-in that downstream tests can import?
- [ ] Does each clever path share the plain signature, match the plain path in a parity test, and carry its note?

## Sources

See `sources.md`, entries Ousterhout (*A Philosophy of Software Design*, *aposd-vs-clean-code*); Go project
(`deps_test.go`); LEGO Group (*LEGO System in Play*); DeepMind (*MuJoCo documentation*); Carpentier (*The Pinocchio
C++ library*); Apple (*WWDC sessions*, *swift-numerics*, *swift-nio*); JAX authors; WebKit (*Project Goals*); PyTorch
(*Design Philosophy*).
