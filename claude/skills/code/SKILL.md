---
name: code
description: The owner's coding principles and the procedure for a code change. Use when writing, changing, refactoring or reviewing code in any language (Python, PyTorch, C++, CUDA, shell): a new feature, module or script, an API or class design, naming, tests, docstrings, a README or docs for code, repository layout, configs and run directories, a commit, a release. Read it before the first edit of a coding task and before judging someone else's code. Not needed for a one-line fix, a config value or a question answered without touching code. For a bug whose cause is unknown use debugging first.
---

# Code

The standard: every decision has a reason, nothing is there by accident, the parts fit together one way, and one person can understand the whole. Code is read far more often than it is written, by people and by agents, and both deserve the same clarity.

Order of authority: the `CLAUDE.md` files first (global, with the project file winning where it explicitly overrides), then a skill the owner invoked for the task (such as autoresearch), then this skill. A chapter is more specific than this page and wins over it. In an existing file the file's own style wins.

## The ten laws

1. **Clarity at the point of use.** Judge every function, class, flag and file by what a call site or a reader sees. A comment that says what a call does means the name is wrong.
2. **One way, one name, one home.** Each task has one obvious path, each thing one name, each artifact one canonical place. When a second way appears, one of the two is removed.
3. **Deep modules, small surfaces.** Hide a lot behind a little. A module earns its interface by the complexity it removes from its callers.
4. **Model, input, state.** A model is built once and never changes. Inputs arrive with each call. The result, called a state, is a pure function of the two, and anything derived from it is derived visibly. Every claim of reproducibility names its scope.
5. **Public is a promise, inside is free.** The public surface is written down and versioned. A public name is removed or changed incompatibly only through a deprecation, a file format only through a format version. The coupling standard that lets parts combine is kept compatible for decades. Everything behind the surface may change whenever a change makes it better.
6. **Say no in writing.** Scope, non-goals and the bar for inclusion are documented. A feature earns its way in by making the whole simpler, not by being possible.
7. **Explicit and loud.** Nothing is guessed, swallowed, probed or silently converted. Missing input, an unknown key in a config, a check that cannot run, an unmet assumption: each one raises, and the message carries the fix. A file format alone may carry fields its reader does not know, so that old readers survive new writers.
8. **Proven, not asserted.** What must always hold is a test or a lint. A bug is not fixed until a test shows it. A number is not a result until its oracle is named. A claim in a document is not true until it is checked against the code.
9. **Write for the reader who is not here.** A person on a phone days later, an agent with no history. Every artifact stands on its own: present tense, no session history, the reason before the detail, a path that resolves.
10. **Subtract first.** Remove before adding, within the scope of the change at hand. The simplest mechanism that meets a measured need wins, and simple beats easy.

## Which bar applies

Decide first what the code promises, because the bar follows the promise.

- **Library**: a public surface for strangers. The surface, the first screen of the docs and the contracts are ideal before they land.
- **Application or research code**: a reproducible result for its owner. Configs are files, each run has its own directory with a manifest, and the stability machinery is relaxed. Every chapter ends with an application profile that lists what is relaxed and what is not.
- **One-off script** that nothing imports: one long function with section guides is fine. Why-only comments, no probing, typed entry points and the formatter still hold.

Inside any of them a change lands when it is better than what it replaces, every regression it causes is stated, and no new known flaw is left untracked.

## Making a change

1. **Scope by reading.** Read the task and the code it touches. List every place the change must reach: callers, tests, fixtures, configs, exports, docs, scripts. Note what it could break or destroy for a user. That list is the scope; extra features are not.
2. **Take the first option that fully works.**
   1. Does it need to exist? Name what you leave out in one line.
   2. Already in this codebase? Use it the way the surrounding code does.
   3. In the standard library or the framework the project already uses? Use it.
   4. In an installed dependency? Use it. A new dependency needs the owner's yes.
   5. Otherwise the minimum code that works, in the structure the codebase already has. Short means quick to read, so a line that needs decoding is not short.
3. **Design from the call site.** For a public function, class or command, write the example call and the one-sentence docstring first. If either is hard to write, change the design before writing the body.
4. **Write it explicit and flat.** A reader with a search box reaches the code that does the work in two hops from a public name. Literal names at call sites, no `hasattr`/`getattr` probing, no behaviour keys in untyped dicts, no silent cast, device move or fallback. One function, one job its name states. In library code a class is abstract or final, and variants are built by composition.
5. **Finish the whole change.** Be minimal about the solution and complete about the change: fix the callers, tests and fixtures it breaks, and remove what it orphans. Code that is moved or merged keeps its validation and error handling. A subagent whose brief limits its paths lists the places outside them in its report and does not edit them.

Never cut for the sake of less code: validation at user-facing boundaries, error handling that prevents data loss, security, and what real hardware needs (calibration constants, offsets, tolerances, unit conversions, clock-drift compensation).

A deliberate shortcut with a known limit carries one comment that starts with `shortcut:` and states the limit and the condition under which it stops being enough (a size, a load, a use case; never a date or a plan step). A later reader then sees a decision, and a search for `shortcut:` lists them. In library code the limit also gets its record in the repository, as 11.2 says.

## Tests

When to write a test is set by `CLAUDE.md` §7: none for research code or one-off scripts unless the owner asks. In library code a bug fix always carries a test that fails without it (6.2), and new logic with a branch, a loop or a parser leaves one small test. In an application, test the glue, not the research (12.7).

When you write one:

- **Name the break first.** Which change to the production code makes this test fail, and is that change a bug? If only an intentional decision can fail it (a constant's value, the wording of a message, private structure), it is a change detector; do not write it. A contract test that enforces a written rule (6.1, 6.10) and a golden with its provenance (6.4) are not change detectors.
- **Take expected values from an independent source**: a literal worked by hand, the spec, the upstream library, autodiff for an analytic derivative, the plain path for a fast path. An expectation computed by the code under test passes whatever that code does. Name the oracle and the tolerance with its dtype.
- **Watch it fail.** A regression test is shown red against the unfixed code, then green with the fix.
- **Replace only what touches the outside world**: hardware, network, time. Use a deterministic stand-in there, never assert on the stand-in itself, and test your own modules for real.
- **Check for gaps before finishing.** Picture a wrong constant, a swapped branch, a missing side effect, an empty return, an input that is zero, empty or malformed. At least one test should fail for each realistic one.
- Seed every random draw from a generator argument. A gate that cannot run fails; it never skips.

## Before you say it works

A claim needs the command that proves it, run after the last edit, and the output line that shows it.

| Claim | Evidence | Not evidence |
|---|---|---|
| Fixed | the original symptom, reproduced before and gone after | the code changed |
| Tests pass | the project's own test command for the tier you name, with counts and every skip named | one file passed |
| Regression test works | red without the fix, green with it | it passed once |
| An agent finished | the diff and a rerun of its check | its report |
| Faster | benchmark command, machine, numbers before and after | it looks cheaper |

Run the project's fast tier before calling a change done, and report every failure by name, including ones the change did not cause. State what was not run and why.

## Reporting a change

Say what changed and why, the net line count, the command and output line for each claim, and close with what was skipped, what was not checked, and any risk the owner must know. Polish you did not do is labelled `Nit:` and written where the next person will find it.

## The chapters

Each numbered chapter opens with its short rule, then numbered principles (rule, why, example, check), an application profile and a checklist that doubles as the review form. Examples cite the owner's projects (BetterRobot, BetterHuman and applications built on them); the rules are generic. Read the chapter before the work it governs:

| Read | Before |
|---|---|
| `references/01-architecture.md` | adding a module or package, changing what imports what, deciding what is model, input or state, adding a cache, a backend or an optional dependency |
| `references/02-api-design.md` | adding or changing a public function, class, flag, default, error type or validation |
| `references/03-naming.md` | naming a module, a public symbol or a tensor, or when a name feels wrong |
| `references/04-code.md` | writing more than a few lines: function shape, classes, comments, docstrings, types, `repr` |
| `references/05-state-determinism-performance.md` | touching randomness, dtype or device, a hot loop, or anything done for speed |
| `references/06-testing.md` | writing or changing tests, goldens, tolerances, test tiers or the runner config |
| `references/07-documentation.md` | writing a README, a docs page, a design note, a changelog entry, or citing code |
| `references/08-decisions-compatibility-releases.md` | a change that is costly to undo, a deprecation, a file format, a release |
| `references/09-repository.md` | creating a repository, moving files, adding data, dependencies or CI |
| `references/10-agents.md` | writing a project `CLAUDE.md`, a nested one, a skill, or a hand-off |
| `references/11-review-and-process.md` | reviewing a change, splitting commits, writing a commit message |
| `references/12-applications.md` | writing a pipeline, a config, a run directory, or code that consumes a library |
| `references/cpp.md` | editing any C++ or CUDA source (`.cpp`, `.cc`, `.cxx`, `.h`, `.hh`, `.hpp`, `.cu`, `.cuh`) |

`references/sources.md` is the bibliography the chapters cite. Chapter references such as "6.2" mean chapter 6, principle 2; "Law 7" means the list above.

## Terms

One name per concept, used the same way in every chapter.

| Term | Meaning |
|---|---|
| model | the constant description of a system, built once |
| input | what a call receives, such as a configuration vector |
| state | the result of a call, derived from model and input; never the input |
| public surface | what a project promises to strangers: exported names, file formats, command lines and their documented behaviour |
| contract | a rule with an identifier and an executed enforcer |
| coupling standard | the few shapes, layouts and file formats through which parts of different projects combine |
| gate | a test that blocks a merge; a threshold is the data it compares against |
| oracle | the independent reference a parity test compares against |
| golden | a stored expected output, with its provenance |
| ratchet | a shrink-only list of known violations, keyed by qualified name |
| exception list | a fixed list of allowed cases, keyed by qualified name or path |
| edge table | the list of allowed imports between packages |
| section | a stage inside one long function, marked by a one-line guide comment |
| level | a depth of an API's progressive disclosure; a layer is a rank in the import graph |
| stand-in | a deterministic replacement for a real backend, used in tests |
| fast tier | the test command that runs in seconds before every commit |
| run directory | the output of one invocation of an application; its run manifest records what ran |
| decision record | the one document that proposes, argues and records a decision |
| agent file | `CLAUDE.md` |
| notes folder | `agent_notes/` |
