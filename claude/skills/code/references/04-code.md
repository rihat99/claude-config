# 4. Code

Code is simple, explicit and flat, so a reader with a search box follows a call from a public name to the code that
does its work in two hops. Delete before adding. A function does one job its name states; a long algorithm keeps its
sections visible with one-line guides, and a function made of separate jobs is split. Every class is abstract or
final and declares everything it offers. Comments say why, docstrings are promises with shapes, the formatter owns
layout, and every public type prints a short summary of itself.

## Principles

### 4.1 Delete before you add [Law 10]
**Why.** Every line is read, tested, ported and explained for as long as it lives. The cheapest complexity is the
complexity never written, and the best refactor removes code. A placeholder that only raises, a parameter nobody
passes and a hook for later all cost the reader without serving a caller. Within a change's own scope, the version
that removes code wins. Dead code found outside that scope is mentioned, not deleted, as the global rules say; it
goes only when the owner asks, in a change of its own.

**Example.** A method whose only job is to say that it does not exist
(`BetterRobot/src/better_robot/spatial/force.py::Force.cross_motion`):
```python
    def cross_motion(self, other) -> "Motion":  # other: Motion
        ...
        raise NotImplementedError(
            "Force.cross_motion is not a standard spatial operation. "
```
Absence says "not supported" on its own.

**Check.** Each change reports its net line count per package, and each removal cites a zero-caller search. A test
keeps the list of every `NotImplementedError` in source equal to the roadmap's list (example:
`tests/contract/test_roadmap_stub_inventory.py`). Review question: what could this change delete?

### 4.2 Write explicit, searchable code: two hops from a public name to its work, and no probing [Law 7]
**Why.** People and agents navigate by search, and each indirection is one more file to open and one more
name to resolve. A literal name at every call site keeps every use findable; dispatch built by reflection,
registration by side effect and identifiers assembled from strings defeat search. A type's declaration is its
promise to readers, type checkers and agents, so an optional member is declared on the abstract type with its
default and called directly; a member found with `hasattr` or `getattr` is invisible to all three, and a misspelled
override falls back to the default without a word. A key that changes behaviour is a typed field of the object that
owns the behaviour, never an entry of an untyped mapping. Code that guesses is easy to write and hard to debug;
explicit code is simple.

**Example.** Optional hooks kept out of the protocol on purpose and found by probing
(`BetterRobot/src/better_robot/data_model/joint_models/base.py::joint_bias_acceleration`):
```python
def joint_bias_acceleration(
    jm: "JointModel", q_slice: torch.Tensor, v_slice: torch.Tensor
) -> torch.Tensor:
    """Dispatch ``c_J`` through ``jm`` if available, else zero."""
    impl = getattr(jm, "joint_bias_acceleration", None)
```
A joint that misspells the hook gets zero bias acceleration and no error.

**Check.** A lint fails on `eval`, `exec` and `hasattr` in library source, and on `getattr` with a literal name
outside the adapter modules on its exception list; reflection over declared structure (`dataclasses.fields`) is
allowed. A module-level `__getattr__` only imports literal names lazily at an optional-dependency boundary. Review
question: from this public name, can a reader reach the code that does its work in two hops, using only search?

### 4.3 Give each function one job its name states, and split a function whose sections are separate jobs [Law 1]
**Why.** A function that does one nameable job can be read, tested and replaced alone. A long algorithm whose
sections share many local values (a recursive pass, a solver step) reads best as one function with a one-line guide
over each section. A function whose sections each produce a named result for the next is a sequence of functions
under one name: the banner over each section is the name its function never got. Deep nesting is the same problem:
each nested block is a function that was never named.

**Example.** Numbered banners in one function, with the size lints silenced
(`BetterRobot/src/better_robot/io/build_model.py::build_model`):
```python
def build_model(  # noqa: PLR0912, PLR0915 - one audited IR packing boundary
    ...
    # ── 1. Identify root structure ────────────────────────────────────────────
    ...
    # ── 19. Pack the one canonical structure/value pair ───────────────────────
```

**Check.** Ruff `PLR0912` and `PLR0915` run at their defaults; a size `noqa` names the shared local values that
forbid a split, and banners are never that reason. Nesting more than four blocks deep fails review. Review question:
could each section guide be a function name?

### 4.4 Make every class abstract or final, and vary behaviour by composition [Law 1]
**Why.** Inheritance is hard to read when an override can sit at any depth: the reader must find which method runs
and where each field was set. If every class is either abstract (it declares an interface and cannot be built) or
final (it can be built and cannot be subclassed), every chain has one step. A final class implements the abstract
members and may override only the hooks its base declares as optional. A variant that tweaks one behaviour wraps the
original or becomes another final class. Exception types are the one exception: a tree of them is how callers catch
by category.

**Example.** One abstract base with its optional hook declared; every concrete layer (`PointsLayer`, `MeshLayer`,
`SkeletonLayer`, ...) subclasses it directly, and none is subclassed
(`BetterRobot/src/better_robot/viewer/layer.py::Layer`):
```python
class Layer(ABC):
    ...
    @abstractmethod
    def build(self, scene: Any, root: str) -> None:
        """Create the scene nodes under ``root`` (a viser scene path such as ``/scene/robot``)."""
    ...
    def build_gui(self, gui: Any) -> None:
        """Add per-layer controls to an open GUI folder; nothing by default."""
```

**Check.** Concrete classes carry `typing.final`. A contract test walks every public class and fails when a class
subclasses a concrete class other than an exception. Review question: which method runs here, and is the answer one
step away?

### 4.5 Comment why, guide long sections in one line, and keep design notes true [Law 9]
**Why.** Code shows what it does; it rarely shows why, or what was rejected. A why comment states the reason, the
constraint or the rejected alternative. A one-line section guide lowers the load of reading a long algorithm with
real sections, and a teacher comment cites the equation the code implements. A design note at the top of a module is
required where behaviour is not obvious from the code and encouraged elsewhere (7.6). Comments that narrate one
line, record history ("removed in phase 3") or keep old code as backup make the reader do work for nothing.

**Example.** A why comment with the rejected alternative
(`BetterRobot/src/better_robot/dynamics/_world.py::inverse_dynamics_full`):
```python
    # Advanced indexing, not index_select: column_owner repeats a joint per column (a free flyer six times), and
    # index_select's CUDA backward adds the repeats with atomics, so its gradients are not bitwise reproducible.
```

**Check.** Ruff `ERA001` rejects commented-out code. Review question for each comment: does it say something the
code cannot? A comment that names a plan step, a phase, a date or a session fails review.

### 4.6 Write each docstring as the function's promise: what it returns, with shapes, then what callers must know [Law 5]
**Why.** A docstring is read instead of the code, so it answers what a caller needs and nothing else. The first
sentence says what the function returns, or what it does if it is called for its effect, with tensor shapes inline
(`q: (B..., nq)`). Then short prose says what the caller must and must not do, what raises, whether the result shares
storage with an input, and what it costs when that is not obvious. Implementation details belong in comments inside
the body. The house style is prose with inline shapes and no section headers, and the first line sits on the same
line as the opening quotes, as the global rules ask. A file that already uses another style keeps it, because the
global rules let a file's own style win; it is converted only in a commit of its own that the owner asked for.

**Example.** A promise in two sentences, including the caller's duty
(`BetterRobot/src/better_robot/optim/problem.py::Problem.residual`):
```text
The declaration is trusted: a row that reads outside its window gives a wrong Jacobian. ``check_jacobian`` tests it.
```

**Check.** A contract test fails on a public function without a docstring, on a tensor parameter whose shape is
absent from it, and on a docstring that cites a missing path (7.8). Review question: can a caller use this function
correctly from the docstring alone?

### 4.7 Make every public signature checkable: typed parameters, one return type, shape aliases from one module [Law 8]
**Why.** Types are the cheapest machine-checked promise, and people and agents read the signature before the body.
The global rules require type hints on public signatures; this rule adds that a checker runs on them and that a
return type never depends on the run-time type of an argument, which shows that the operation should be two
functions. Shapes do not fit in Python types, so they live in docstrings, and named aliases for common shapes live in
one module.

**Example.** An untyped operator whose result type depends on what it receives
(`BetterRobot/src/better_robot/lie/types.py::SO3.__matmul__`):
```python
    def __matmul__(self, other):
        if isinstance(other, SO3):
            return self.compose(other)
        if _is_point(other):
            return self.act(other)
        return NotImplemented
```

**Check.** Ruff `ANN001` and `ANN201` hold in library source, with a ratchet (6.1) while violations remain; `mypy`
or `pyright` runs on the public modules. Review question: can the return type be written without `Any` or a union
over unrelated types?

### 4.8 Let the formatter own layout [Law 2]
**Why.** When all code looks the same, nobody translates layouts, diffs show only real changes, and no review
discusses spacing. Agents produce no formatting noise when a formatter runs. A formatter escape is allowed only for a
data literal whose alignment carries meaning, such as a table of faces or a matrix. If the formatted code looks
wrong, restructure the code. A repository is formatted once, in a commit that changes nothing else (11.4).

**Example.** An escape where the layout is the content (`BetterRobot/src/better_robot/viewer/_math.py::unit_box`):
```python
    faces = np.array(
        [[0, 1, 3], [0, 3, 2], [4, 6, 7], [4, 7, 5], [0, 4, 5], [0, 5, 1],
         [2, 3, 7], [2, 7, 6], [0, 2, 6], [0, 6, 4], [1, 5, 7], [1, 7, 3]],
        dtype=np.uint32,
    )  # fmt: skip
```

**Check.** `ruff format --check` runs in CI and before every commit, in the pre-commit hook. A test lists every
`fmt: off` and `fmt: skip` in library source, and each one sits on a data literal.

### 4.9 Give every public type a short, useful `repr` [Law 9]
**Why.** A `repr` is what a person sees in a debugger and what an agent sees in a traceback or a log. The generated
`repr` of a dataclass that holds a model prints every tensor and table, tens of thousands of characters for a small
robot, which buries the one line that matters and fills an agent's context. A summary names the object and the few
facts that identify it: name, sizes, dtype, device.

**Example.** The shape of a useful summary:
```python
def __repr__(self) -> str:
    """One line: name, sizes, dtype and device."""
    return f"Model({self.name!r}, nq={self.nq}, nv={self.nv}, njoints={self.njoints}, {self.dtype}, {self.device})"
```

**Check.** A contract test builds each public type from the test fixtures and asserts that its `repr` is one line
under 200 characters and contains its name. Large dataclasses set `repr=False` on tensor fields.

## Application profile

Relaxed:
- 4.1's net line count is reported per stage, not for the whole application.
- 4.4 and 4.9 apply to types that cross a stage boundary or reach an output file.
- A one-off script that nothing imports (a figure, a data import) may keep one long function with section guides
  (4.3).

Not relaxed:
- Why-only comments with no history (4.5), and no probing (4.2).
- Docstring promises with shapes for every stage entry point (4.6), and typed stage signatures (4.7).
- The formatter (4.8).

## Checklist
- [ ] Does the change delete what it can, add no placeholder or dead parameter, and report its net line count?
- [ ] Can a reader reach each public name's work in two hops by search, with no probing and no untyped behaviour key?
- [ ] Does each function do one job its name states, with section guides only where sections share values?
- [ ] Is every class abstract or final, with variants built by composition?
- [ ] Does every comment say why, guide a section, or cite an equation, and is every design note true?
- [ ] Does every public docstring open with what it returns, with shapes, then state duties, errors, aliasing and cost?
- [ ] Is every public signature typed and checked, with no return type that depends on an argument's run-time type?
- [ ] Is the code formatted by the formatter, with escapes only on data literals?
- [ ] Does every public type print a one-line summary?

## Sources

See `sources.md`, entries Redis (*MANIFESTO*); Rams (*Ten principles for good design*); McKinley (*Choose Boring
Technology*); Fitzpatrick and Crawshaw (*An unlikely database migration*); Ronacher (*Agentic Coding
Recommendations*); Hugging Face (*How to add a model to Transformers*); Ousterhout (*A Philosophy of Software
Design*); Hickey (*Simple Made Easy*); Kidger (*Equinox*); antirez (*Writing system software: code comments*); Go
project (*Go Doc Comments*); Rust project (*Rust API Guidelines*); Swift project (*API Design Guidelines*); Gerrand
(*go fmt your code*); Pike (*Go Proverbs*).
