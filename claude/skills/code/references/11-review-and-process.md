# 11. Review and process

The public surface, the first screen of the docs and the contracts are ideal before they land. Inside, a change lands
when it is better than what it replaces, every regression it causes is stated and accepted in the review, and no new
known flaw is left untracked; remaining polish is labelled `Nit:` and either fixed or recorded. A review reads in a
fixed order, from the public surface down to nits, and every commit is one change whose message says why and what
was run. Changes the owner must decide start as a decision record, important results get an independent
adversarial pass, and a gate's data changes only in a commit of its own.

## Principles

### 11.1 Hold the public surface to the ideal, and the inside to better than before [Law 5]
**Why.** The public surface is a promise to strangers: once code depends on a name, a default, an error or a file
layout, fixing it costs a migration for every user. The inside can be improved by the next change, at the cost of
that change alone. So the public surface (8.4), the first screen of the docs and the contracts are ideal before
they land. Inside, a change lands when it is better than what it replaces, every regression it causes is stated and
accepted in the review, and no new known flaw is left untracked (11.2). A change that is simpler and slower meets
this bar when its slowdown is written down (5.8).

**Example.**

| Lands only when ideal | Lands when better than before |
|---|---|
| names, signatures, defaults and errors of public modules | function bodies and private helpers |
| file formats and their versions | private modules and their layout |
| CLI flags, config keys, output trees | test internals and fixtures |
| the first screen of the docs | tools, benchmarks, CI plumbing |
| contracts and their enforcers | comments inside function bodies |

**Check.** Review questions: does the diff touch the public surface? If it does, is each changed name, default,
error and doc line the one to keep for a decade? If it does not, is the result better than what it replaces, and is
every regression stated?

### 11.2 Label polish `Nit:`, then fix it in the same change or record it where the next person will find it [Law 5]
**Why.** A review comment is either a defect that blocks the merge or polish that does not, and the label makes the
difference visible, so polish never stalls work and defects never pass as taste. Facts and measurements overrule
opinions. On formatting the formatter is the authority, and a design question is never "just style". A record lives
in the repository: an issue, a ratchet entry keyed by qualified name (6.1), or a roadmap row. A chat, a closed review
thread or an ignored notes folder is not a record.

**Example.**
```text
Blocking: `solve` returns a view into `x0`, but the docstring promises a copy. Copy it or fix the docstring.
Nit: `tmp` holds the world-from-frame transform; call it `world_from_frame`.
```

**Check.** Every review comment starts with `Blocking:` or `Nit:`. Every `Nit:` left unfixed at merge has a tracked
record.

### 11.3 Review in a fixed order, from the public surface down to nits [Law 5]
**Why.** The costliest defects are the hardest to see in a function body. A reviewer who starts with naming spends
attention before reaching a broken contract. The author runs the same order over the diff before asking anyone, and
an agent runs it before it hands work back. A short fixed list covers most review comments; the chapter checklists
are the long form.

**Example.** The short review checklist:
```text
1. Public surface: which names, defaults, errors, formats, CLI flags or config keys change? Is each one final?
2. Tests: does a test fail without this change? Does every claim in the description carry its command?
3. Contracts: does a rule, an edge table, a ratchet or a threshold change? Is that in its own commit (11.7)?
4. Design: is there one way to do it? Is the module deep? Is anything guessed that could be declared?
5. Docs: does the first screen still tell the truth? Do the snippets run?
6. Code: names, comments that explain why, no silent fallback, no dead code.
7. Scope: is every changed line needed for the stated goal?
8. Nits: labelled, then fixed or recorded.
```

**Check.** Review comments follow the list's order. Review question: did the review settle the public surface, the
tests and the contracts before it reached naming and style?

### 11.4 Make each commit one self-contained change, and put mechanical changes in commits of their own [Law 9]
**Why.** A small commit is read whole, found by bisection, and reverted without collateral loss. About 100 changed
lines is a comfortable review; 1,000 is too many to read with care. A formatting sweep or a rename inside a behaviour
change hides the behaviour; alone, it is reviewed in a minute by checking that it is mechanical. This extends the
global rule of surgical diffs from lines to commits.

**Example.** `BetterRobot` commit `20862fe`, "Armature in RNEA, capsule self-collision, MJCF fromto, reproducible
point posing, one-evaluation L-BFGS step", puts five independent changes into one commit. Each belongs in a commit
of its own.

**Check.** The subject names one change. Review question: could half of this commit be reverted alone? Then it is two
commits.

### 11.5 Write commit messages that say why, what changed, and how it was verified [Law 9]
**Why.** The diff shows what changed. Only the message can say why, and only the author knows what was run. A later
reader who bisects or blames needs the reason more than the summary. A fixed shape turns the message into a
checklist for its author.

**Example.** The subject follows the repositories' `<Area>: <change>` form:
```text
<Area>: <one change, under 72 characters>

Why: <the defect or need, as a user observes it>
What: <the change, one line per part>
Test: <path::test that fails without this change>   or   No test: <reason (6.2)>
Verified: <command> -> <output line>

<trailers such as Co-Authored-By, when the project uses them>
```

**Check.** Review question: does the body say why, and what was run?

### 11.6 Start with a decision record before a change that is costly to undo [Law 6]
**Why.** These changes set the architecture or the shape of the API, or add a dependency, and the global rules leave
each of those to the owner; they are also the costliest to undo. A page of writing is cheaper than a reverted diff
and surfaces the alternatives while they are cheap. The record uses the one template of 8.2, starts in status
Proposed, and lists what the owner must answer. Six kinds of change need one:

1. a change to the public surface (8.4) that is not an addition;
2. an added dependency;
3. an added file format or format version (8.7);
4. a change to the coupling standard (1.3);
5. an added edge in the edge table (1.1);
6. a second backend, a custom kernel, a compile wrapper or a cache (5.6).

Internal work larger than about an hour gets a plan instead (9.7).

**Example.** Removing `Model.fk` (1.1) takes a name off the public surface, so it starts as a record in status
Proposed that shows the call site after the change, `forward_kinematics(model, q)` (3.2), and the deprecation entry
that carries users across (8.9).

**Check.** A diff that makes a change of one of the six kinds links an accepted decision record. Review question:
does this diff remove or change a public name, add a dependency, a format, a format version, an edge, a backend, a
kernel, a compile wrapper or a cache, or touch the coupling standard?

### 11.7 Change a gate's data only in a commit of its own, never to land another change [Law 8]
**Why.** A gate's data guards correctness or structure: a parity tolerance, an edge table, a ratchet, an exception
list, a performance threshold. Loosening one to make a change pass hides exactly the defect the gate exists to
catch. In its own commit, the change is visible and is reviewed as a change to a contract. The one exemption is a
ratchet entry removed or lowered in the same commit as the fix that resolves it, because the stale-entry test (6.1)
needs both together. The global rules forbid skipping, xfailing or weakening a test to get a green run; this rule
extends that to a gate's data.

**Example.** The policy stated above the edge table it guards
(`BetterHuman/tests/contract/test_layer_dependencies.py`):
```python
"""H-LAYER-1: imports inside ``better_human`` follow the package DAG.

``core`` and ``io`` import nothing from the package; ``families`` imports ``core`` and ``io``; ``terms`` imports
``core``; ``viz`` imports anything below it and the package root. The edges below are the ones that exist; adding
one is a contract decision.
"""
```

**Check.** A commit that edits a tolerance, an edge table, a ratchet, an exception list or a threshold touches
nothing else, unless it only removes or lowers the ratchet entries that its own fix resolves, and its message has a
`Why:` line.

### 11.8 Send important results to an independent adversarial review before calling them done [Law 8]
**Why.** The author's review is anchored on the author's reasoning. A reviewer with a clean context, given the code,
the data and the commands but not the author's verdict, finds what the author cannot see. Important means: a change
to the public surface, a number that drives a decision (a benchmark, a parity figure, a results table), a conclusion
in a report, and any change to a gate's data except ratchet entries that a fix removes or lowers (11.7). The global
rules require an adversarial pass for important code, numbers and conclusions before they are called done; this rule
says what counts as important and how the pass is recorded. The author checks each finding and marks it
confirmed, refuted with the reason, or unclear with what would settle it.

**Example.** The brief states claims that can be false, and the record keeps every finding (illustrative):
```markdown
Claims under review:
1. Inverse dynamics with armature matches Pinocchio to 1e-10 on every joint kind.
2. The solver step performs no host sync.

| # | Finding | Severity | Status | Change |
|---|---|---|---|---|
| 1 | Claim 1 is tested in float64 only | major | confirmed | float32 parity case added |
| 2 | `.item()` in the line search | minor | refuted: the line search is the documented exception | none |
```

**Check.** The report or pull request carries the findings table, and refuted findings stay in it with their reason.

## Application profile

Relaxed:
- Research and one-off scripts need no test with a fix unless the owner asks (6.2, the global rules).

Not relaxed:
- An application's public surface (8.4) and its README results table are held to the ideal; the inside to better
  than before, as in a library.
- 11.6 also covers a method choice that changes results: the record names the expected effect and the metric that
  decides.
- 11.8 applies to every number in a results table.

## Checklist
- [ ] Is every change to the public surface ideal, and is every internal change better, with each regression stated?
- [ ] Is each review comment labelled `Blocking:` or `Nit:`, with every unfixed nit recorded in the repository?
- [ ] Did the author and the reviewer go through the short checklist in order?
- [ ] Is each commit one change, with formatting and renames in commits of their own?
- [ ] Does each commit message say why, what changed, and what was run?
- [ ] Did every change of a kind that 11.6 lists start as a decision record in the template of 8.2?
- [ ] Is every change to a gate's data in its own commit with its reason, apart from ratchet entries its own fix
  removes or lowers?
- [ ] Did every important result pass an independent adversarial review, with all findings recorded?

## Sources

See `sources.md`, entries Google (*Engineering Practices*); Drake (*Code review checklist*); SQLite (*How SQLite Is
Tested*); WebKit (*Contributing Code*); Apple (*swift-nio*); Rust project (*RFC template*); Swift project (*Swift
Evolution*); Go project (`deps_test.go`); Owner (*Global working rules*, *Skills*).
