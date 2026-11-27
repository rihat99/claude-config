# 3. Naming

A name is the first documentation a reader meets, so it carries what the call site needs. Name things by their
role, in full words, with abbreviations and math notation taken from one glossary per stack. One concept has one
name across every repository of a stack, and one name means one concept. Grammar carries information: a pure
function is named for what it returns, an effect is a verb, a predicate is an assertion, and a tensor is plural
exactly when it has an axis over named things.

## Principles

### 3.1 Name by role at the point of use, in full words, with length that grows with distance from the declaration [Law 1]
**Why.** A call site shows names, not types. In tensor code every argument is a `Tensor`, so the keyword is the only
thing that tells a reader what goes where (`frame=`, `target=`, `q0=`). A name for the role (`targets`) beats a name
for the type (`pose_dict`). Every word must add information at the use site: `get_` before a pure accessor adds
nothing. A loop index may be `i`; a public field read across the codebase spells itself out.

**Example.** An abbreviation outside the glossary on a field read everywhere, and a needless verb on accessors
(`BetterRobot/src/better_robot/data_model/model.py::Model`):
```python
model.lower_pos_limit              # lower_position_limit
model.get_subtree(joint)           # model.subtree(joint)
model.get_support(joint)           # model.support(joint)
```

**Check.** Ruff `N` rules run outside the math packages, and the glossary test (3.9) checks every word of every
public name. Review question: read the call site aloud; does any word carry no information, or is any role unclear
without the signature?

### 3.2 Let grammar announce the effect: nouns for results, verbs for effects, assertions for predicates [Law 1]
**Why.** A reader decides from the name alone whether a call is safe to repeat, whether it changes anything, and what
comes back. A pure function is named for the quantity it returns or for the field's term of art (`mass_matrix`,
`inverse_dynamics`), never with the return type appended. A function or method with an effect is an imperative verb
(`viewer.add`, `builder.add_body`). A copy with one change starts with `with_`. A conversion is `to_` or `from_` and
says what it loses. A boolean reads as an assertion (`is_closed`, `has_mass`), and a boolean flag is named for its
true case.

**Example.** The grammar at work in one library (`BetterRobot/src/better_robot/`):
```python
tau = inverse_dynamics(model, state, v=v, a=a)          # noun: what comes back
viewer.add(layer)                                        # verb: an effect
tuned = model.with_values(joint_placements=placements)  # copy with one change
rpy = so3.to_euler(quat_xyzw)                            # lossy: its docstring states the gimbal-lock rule
```
Its forward kinematics breaks the rule: `forward_kinematics_state` appends the return type, while its siblings
`inverse_dynamics`, `forward_dynamics` and `mass_matrix` do not. The consistent name is `forward_kinematics`, and the
old name leaves through the deprecation table (8.9).

**Check.** A lint on public names flags `get_`, `do_` and type-name suffixes. Review question: from the name alone,
does a reader know whether the call has an effect and what it returns?

### 3.3 Name a tensor in the plural when it has an axis over named things, and in the singular otherwise [Law 1]
**Why.** The name announces the shape. An axis over joints, frames, bodies, vertices or markers makes a name
plural. Batch axes never do, and neither do component axes (the 7 numbers of a pose, the `nq` coordinates of one
configuration). Then `frame_poses` and `frame_pose_of("hand")` differ in exactly the way their shapes differ, and a
reader can index without opening the docs.

**Example.** The rule applied:
```text
state.frame_poses                (B..., nframes, 7)   axis over frames: plural
state.frame_pose_of("hand")      (B..., 7)            one frame: singular
state.vertices                   (..., V, 3)          axis over vertices: plural
q                                (B..., nq)           one configuration per batch element: singular
model.lower_position_limit       (nq,)                coordinates of one configuration: singular
```
`BetterRobot` names `KinematicState.frame_pose` `(B..., nframes, 7)` in the singular and
`ModelValues.joint_placements` `(njoints, 7)` in the plural, and `BetterHuman` names `HumanState.joint_poses`
`(..., J, 7)` in the plural: two forms for one kind of axis.

**Check.** A contract test reads the shape in each public field's docstring and fails when an entity axis
(`njoints`, `nframes`, `nbodies`, `J`, `V`) meets a singular name, or a shape without one meets a plural name. Review
question: does the name's number match the shape?

### 3.4 Give one concept one name across the stack, and one name only one concept [Law 2]
**Why.** Two names for one thing (an alias, an abbreviation kept beside the full name) make readers ask whether they
differ, and they double what an agent must search for. One name for two things is worse: an import silently picks the
wrong one. A stack of libraries and the applications on top of them share one vocabulary, so a higher layer does not
reuse a type name of a layer it imports, and a wrapper is named for what it adds. The one exemption is a name in the
deprecation table (8.9): it lives beside its replacement until its removal version.

**Example.** Two names for one thing, and one name for three things:
```text
Pose = SE3                 BetterRobot/src/better_robot/lie/types.py
better_robot.Body          a rigid body record (BetterRobot/src/better_robot/data_model/body.py)
better_human.Body          a body family on a device (BetterHuman/src/better_human/core/body.py)
bvr.body.Body              an application wrapper over better_human.Body (BetterVideoReconstruction/bvr/body.py)
```

**Check.** A contract test fails on module-level aliases of public types and on method aliases of public functions,
except names in the deprecation table. Each repository's contract test lists the public type names of the libraries
it imports and fails when one of its own public types reuses one. Review question: does this name already mean
something in a layer below?

### 3.5 Write an acronym in capitals inside CapWords and in lower case inside snake_case [Law 2]
**Why.** Mixed rules make names unguessable: a reader who knows one spelling cannot find the other by search, and an
agent writes the wrong one. One rule ends the question. Capitals inside CapWords match PEP 8, and an acronym then
looks the same in prose, in class names and in the glossary.

**Example.** Both forms in one package, and the rule's form (`BetterHuman/src/better_human/families/`):
```text
MHRClassic (mhr.py)     MhrRig (mhr_rig.py)      ->  MHRRig
SOMAClassic (soma.py)   SomaRig (soma_rig.py)    ->  SOMARig
mhr_from_classic                                      snake_case: lower case
```

**Check.** A contract test lists the stack's acronyms (`MHR`, `SOMA`, `SMPL`, `SMPLX`, `MANO`, `FLAME`, `SE3`, `SO3`)
and fails on any public class name that spells one in mixed case.

### 3.6 Keep the names that users and source files gave, and take names, not indices, at every user boundary [Law 1]
**Why.** A user who named a link `panda_hand` in a URDF expects to find `panda_hand`. A generated prefix means every
first example must teach the prefix. An integer index at a user boundary forces a lookup table into the caller's
code, together with a comment to explain it, and breaks when the order changes. Names are stable across files and
versions; indices are an internal detail.

**Example.** A magic index with a comment standing in for a name (`BetterHuman/examples/03_ik_reach.py`):
```python
WRIST = 20  # native joint index of left_wrist
problem.residual("wrist", terms.joints(target="target", joint_ids=[WRIST]))
```
In the same way, the URDF link `panda_hand` becomes the frame `body_panda_hand` in `BetterRobot/README.md`.

**Check.** A test loads a reference URDF and asserts that every link and joint name appears unchanged. Every public
parameter that identifies a joint, frame or body accepts `int | str`. If two source objects share a name, loading
raises or applies one rule documented on the first screen.

### 3.7 Use monogram notation for frame-dependent quantities inside math code, and full words everywhere a user looks [Law 1]
**Why.** Monogram notation writes the quantity first, then its frames: `X_AB` is the pose of frame B in frame A,
`p_AoBo_W` a position from A's origin to B's origin expressed in W. Composition then checks by rote: in
`X_WB = X_WA @ X_AB` the inner letters cancel. Agents and reviewers do rote checks well. The notation is a
specification for comparing code with the theory; it stays inside math modules and private helpers, and never
reaches a public name.

**Example.** Math code whose names do not say which frames compose
(`BetterRobot/src/better_robot/kinematics/jacobian.py::frame_jacobian_time_variation_raw`):
```python
    T_parent = torch.index_select(joint_pose_world, -2, parent_index).squeeze(-2)
    T_frame = se3.compose(T_parent, T_local)
```
In monogram form the same line checks itself: `X_WF = se3.compose(X_WP, X_PF)`.

**Check.** Ruff `N803` and `N806` are ignored only in the math packages. Review question: in each composition, do
the inner frames of the names cancel?

### 3.8 Name a module for what it computes and for what its functions need [Law 1]
**Why.** A module named for its input type (`state.py`) says nothing about its job, and two such modules in two
packages hold unrelated algorithms under one name. A module named for its computation is found by search. The
package name can also announce dependencies: functions in `lie` and `spatial` take tensors only, functions in
`kinematics` and `dynamics` take a model. A name like `utils`, `common`, `misc` or `helpers` announces nothing. File
names follow the global rules: the repository's existing convention first, `category_specific.py` for a family of
internal implementations, plain descriptive names for public modules, and one main class per file. When a family
outgrows its prefix, at three or more modules that share it, the category becomes a folder and the prefix drops
(`joint_models/revolute.py`).

**Example.** Modules named for an input type or placed by the wrong name (`BetterRobot/src/better_robot/`,
`BetterHuman/src/better_human/`):
```text
dynamics/state.py              holds inverse_dynamics, mass_matrix, forward_dynamics (RNEA, CRBA, ABA)
kinematics/state.py            holds forward kinematics and the Jacobians
io/parsers/programmatic.py     holds ModelBuilder, which is not a parser; io/builders/ holds another builder
better_human/terms.py          exports project(points, camera), which is not a term
```

**Check.** A test fails on public modules named `utils`, `common`, `misc` or `helpers`. Review question: does the
module name say what the module computes, and does every public name in it belong there?

### 3.9 Keep one glossary per stack, and use its words everywhere [Law 2]
**Why.** A glossary is where a name is decided once. Without it each module invents its own word, and each agent
session another. The glossary defines each term once, with its symbol and shape; docs, docstrings and identifiers use
its word, and a term enters it in the change that introduces it. The lowest library's glossary is canonical, and
higher layers add only their own words. A term of art belongs in it when an expert would expect it and a web search
finds it (`q`, `nq`, FK, Jacobian, placement). A vocabulary that matters is enforced by a test that rejects its
synonyms.

**Example.** Three words for rigid-body quantities, each with one meaning, checked over every public name, field and
parameter (`BetterRobot/docs/contracts/01-naming.md`, C-NAME-5; `BetterRobot/tests/contract/test_se3_vocabulary.py`):
```text
placement   a pose in the parent frame (model constants)   (..., 7)
pose        a computed world quantity                       (..., 7)
transform   the same world quantity as a matrix             (..., 3, 4)
rejected    tf, xform, homogeneous, pose_matrix, world_placement
```

**Check.** One test per controlled vocabulary (example: `tests/contract/test_se3_vocabulary.py`), and one test that
splits every public name into words and checks each abbreviation against the glossary. Review question: does this
change introduce a term, and is it in the glossary with this meaning and spelling?

## Application profile

Relaxed:
- An application keeps no glossary of its own; it uses its libraries' glossary and lists its domain words in its
  agent file.
- 3.5 and 3.8 apply to modules that other repositories import; internal scripts follow the global rules only.

Not relaxed:
- An application never reuses a library type name for its own wrapper (3.4).
- Configs take names, not indices (3.6).
- Configs, logs and output files use the libraries' names for every shared quantity (3.3, 3.9).

## Checklist
- [ ] Does every name state its role at the call site, in full words or glossary terms, with no needless word?
- [ ] Do the names say what comes back, what changes, and what a predicate asserts?
- [ ] Is every tensor name plural exactly when its shape has an axis over named things?
- [ ] Does each concept have one name across the stack, with no alias outside the deprecation table?
- [ ] Are acronyms capitals in CapWords and lower case in snake_case?
- [ ] Do names from users and source files survive unchanged, and do user boundaries take names?
- [ ] Does math code use monogram notation whose frames cancel, and no public name use it?
- [ ] Is each module named for what it computes, with nothing in it that its name does not cover?
- [ ] Is every term and abbreviation in the stack glossary, with controlled synonyms rejected by a test?

## Sources

See `sources.md`, entries Swift project (*API Design Guidelines*); WebKit (*Code Style Guidelines*); Go project
(*Effective Go*, *Code Review Comments*); DeepMind (*MuJoCo documentation*); Python (*PEP 8*); Drake (*Monogram
notation*).
