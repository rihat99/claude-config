# Sources

One entry per source used by the research behind the chapters. A chapter cites a source by author and title; the
link lives here. "(secondary)" marks a source read through a copy, a reproduction or a summary rather than the
primary text. "(unverified)" marks a source that could not be read; nothing in a chapter rests on it alone.
Entries are alphabetical within each group.

## Apple and Swift

- Apple. *FoundationDB testing* and source (`flow/include/flow/Buggify.h`, `fdbclient/ClientKnobs.cpp`).
  https://apple.github.io/foundationdb/testing.html , https://github.com/apple/foundationdb
- Apple. *Human Interface Guidelines*: iOS Themes (2020) and OS X Design Principles (2016), via the Wayback
  Machine; *Liquid Glass* overview (2025), https://developer.apple.com
- Apple. *swift-async-algorithms*: Effects guide, Evolution template and `0001-zip.md`, AsyncSequenceValidation,
  `TestDebounce.swift`. Commit `cbde9aed`. https://github.com/apple/swift-async-algorithms
- Apple. *swift-collections*: README, `Documentation/Internals/README.md`, `ReleaseChecklist.md`, `OrderedSet`
  sources. Commit `f96b909e`. https://github.com/apple/swift-collections
- Apple. *swift-nio*: README, `docs/public-api.md`, `docs/debugging-allocations.md`, performance thresholds,
  `dev/git.commit.template`, semver label checker. Commit `108daca3`. https://github.com/apple/swift-nio
- Apple. *swift-numerics*: README, ComplexModule README, `ApproximateEquality.md`. Commit `669f6185`.
  https://github.com/apple/swift-numerics
- Apple. *WWDC sessions* 2019/216 SwiftUI Essentials, 2019/226 Data Flow Through SwiftUI, 2019/415 Modern Swift
  API Design, 2019/722 Introducing Combine, 2020/10040 Data Essentials in SwiftUI, 2021/10022 Demystify SwiftUI.
  https://developer.apple.com/videos/
- Apple. *xnu documentation*: `doc/primitives/string-handling.md`, `doc/allocators/api-basics.md`.
  https://github.com/apple-oss-distributions/xnu
- Burrows, Peter. *The Seed of Apple's Innovation*. BusinessWeek, 2004. Via the Wayback Machine.
- BusinessWeek. *Steve Jobs: "There's Sanity Returning"*. 1998. Via the Wayback Machine.
- Fortune. *The day Steve Jobs told Nike...*, quoting Betsy Morris's 2008 Fortune interview. 2011.
  https://fortune.com/2011/05/17/video-the-day-steve-jobs-told-nike-you-make-a-lot-of-crap/ (secondary for the
  2008 original)
- Gruber, John. *Working Backwards*, a transcription of Steve Jobs at WWDC 1997. Daring Fireball, 2014.
  https://daringfireball.net/2014/02/working_backwards (secondary)
- Richmond, Shane. *Jonathan Ive interview: simplicity isn't simple*. The Telegraph, 2012. Via the Wayback Machine.
- Sheff, David. *Playboy Interview: Steven Jobs*. Playboy, 1985. Read in a reproduction:
  https://www.cultofmac.com/news/revisiting-steve-jobs-classic-playboy-interview (secondary)
- Swift project. *API Design Guidelines*. https://www.swift.org/documentation/api-design-guidelines/
- Swift project. *Error Handling Rationale and Proposal*, `docs/ErrorHandlingRationale.md`.
  https://github.com/swiftlang/swift
- Swift project. *github-workflows*, `soundness.yml` (API breakage check). Tag `0.0.10`.
  https://github.com/swiftlang/github-workflows
- Swift project. *Library Evolution Support in Swift*, `docs/LibraryEvolution.rst`. https://github.com/swiftlang/swift
- Swift project. *Swift Evolution*: `process.md`, proposal template, `commonly_proposed.md`, SE-0427
  Noncopyable Generics, the Approachable Concurrency vision. Commit `0bc0e34e`.
  https://github.com/swiftlang/swift-evolution
- Swift.org. *Introducing Swift Collections*. 2021. https://www.swift.org/blog/swift-collections/
- Walker, Rob. *The Guts of a New Machine*. The New York Times Magazine, 2003.
  https://www.nytimes.com/2003/11/30/magazine/the-guts-of-a-new-machine.html
- WebKit. *Code Style Guidelines*, *Contributing Code*, *Performance*, *Project Goals*.
  https://webkit.org/code-style-guidelines/ , https://webkit.org/contributing-code/ ,
  https://webkit.org/performance/ , https://webkit.org/project/
- Zhou, Jingyu, et al. *FoundationDB: A Distributed Unbundled Transactional Key Value Store*. SIGMOD, 2021.
  https://www.foundationdb.org/files/fdb-paper.pdf

## Language and library design

- Asjes, Paul. *Designing APIs for humans: Object IDs*. Stripe on DEV, 2022. https://dev.to/stripe
- Carpentier, Justin, et al. *The Pinocchio C++ library*. IEEE/SICE SII, 2019. https://hal.laas.fr/hal-01866228
- Cox, Russ. *Backward Compatibility, Go 1.21, and Go 2*. 2023. https://go.dev/blog/compat
- Cox, Russ. *Semantic Import Versioning*. 2018. https://research.swtch.com/vgo-import
- DeepMind. *MuJoCo documentation*: Overview, Simulation, Programming (naming convention).
  https://mujoco.readthedocs.io
- Drake. *Monogram notation*. https://drake.mit.edu/doxygen_cxx/group__multibody__notation__basics.html
- Drake. *Stability guarantees*, rolling deprecation window. https://drake.mit.edu/stable.html (the removal-date
  rule of `DRAKE_DEPRECATED`: secondary)
- Gerrand, Andrew. *go fmt your code*. 2013. https://go.dev/blog/gofmt
- Go project. *Effective Go*, *Go Doc Comments*, *Code Review Comments*. https://go.dev/doc/effective_go ,
  https://go.dev/doc/comment , https://go.dev/wiki/CodeReviewComments
- Go project. *Go 1 and the Future of Go Programs*; *Go 1.4 Release Notes* (internal packages).
  https://go.dev/doc/go1compat , https://go.dev/doc/go1.4
- Go project. Source: `src/go/build/deps_test.go`, `src/io/io.go`. Commit `9dd31ba8`. https://github.com/golang/go
- JAX authors. *Stateful computations*, *Pytrees*, *Pseudorandom numbers*. https://docs.jax.dev/en/latest/
- Kidger, Patrick. *Equinox*: All of Equinox, the abstract/final pattern.
  https://docs.kidger.site/equinox/all-of-equinox/ , https://docs.kidger.site/equinox/pattern/
- Kidger, Patrick. *jaxtyping*. https://github.com/patrick-kidger/jaxtyping (unverified: project description not
  re-read)
- Leach, Brandur. *APIs as infrastructure: future-proofing Stripe with versioning*. 2017.
  https://stripe.com/blog/api-versioning
- Leach, Brandur. *Designing robust and predictable APIs with idempotency*. 2017. https://stripe.com/blog/idempotency
- Pike, Rob. *Go Proverbs*. https://go-proverbs.github.io
- Preston-Werner, Tom. *Semantic Versioning 2.0.0*. https://semver.org
- Python. *PEP 8, Style Guide for Python Code*; *PEP 20, The Zen of Python*. https://peps.python.org/pep-0008/ ,
  https://peps.python.org/pep-0020/
- Python. *PEP 723, Inline script metadata*. https://peps.python.org/pep-0723/
- PyTorch. *Design Philosophy*; *Reproducibility*; *torch.func UX limitations*.
  https://docs.pytorch.org/docs/2.15/community/design.html , https://docs.pytorch.org/docs/2.15/notes/randomness.html ,
  https://docs.pytorch.org/docs/2.15/func.ux_limitations.html
- Rust project. *Rust API Guidelines*. https://rust-lang.github.io/api-guidelines/
- SQLite. *Database File Format*; *SQLite As An Application File Format*; *Long Term Support*; *LoC Recommended
  Storage Format*. https://sqlite.org/fileformat2.html , https://sqlite.org/appfileformat.html ,
  https://sqlite.org/lts.html , https://sqlite.org/locrsf.html
- Wright, Hyrum. *Hyrum's Law*. https://www.hyrumslaw.com

## Testing

- 15r10nk. *inline-snapshot*. https://15r10nk.github.io/inline-snapshot/latest/
- Hugging Face. *How to add a model to Transformers*: parity at 1e-3, staged comparison, dummy weights, design
  philosophy. https://huggingface.co/docs/transformers/main/en/add_new_model
- import-linter. *Contracts*: layers, independence, forbidden. https://import-linter.readthedocs.io/en/stable/
- Mineault, Patrick. *The Good Research Code Handbook: testing*. https://goodresearch.dev/testing
- pydantic. *pytest-examples*. https://github.com/pydantic/pytest-examples
- PyTorch. *torch.testing*, `assert_close` tolerances. https://docs.pytorch.org/docs/2.15/testing.html
- Scientific Python. *Development Guide: pytest*. https://learn.scientific-python.org/development/guides/pytest/
- SQLite. *How SQLite Is Tested*. https://sqlite.org/testing.html
- SQLite. *The Use Of assert() In SQLite*. https://sqlite.org/assert.html

## Documentation and process

- ashleve. *lightning-hydra-template*. https://github.com/ashleve/lightning-hydra-template
- Astral. *uv: project layout and lockfile*. https://docs.astral.sh/uv/concepts/projects/layout/
- Drake. *Code review checklist*. https://drake.mit.edu/code_review_checklist.html
- DrivenData. *Cookiecutter Data Science: opinions*. https://cookiecutter-data-science.drivendata.org/opinions/
- GitHub. *About large files on GitHub*.
  https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github
- Google. *Engineering Practices*: The Standard of Code Review, What to look for, Small CLs, Speed of code
  reviews. https://google.github.io/eng-practices/
- Karpathy, Andrej. *nanoGPT*, README. https://github.com/karpathy/nanoGPT
- Kladov, Aleksey. *ARCHITECTURE.md*. 2021. https://matklad.github.io/2021/02/06/ARCHITECTURE.md.html
- Lacan, Olivier. *Keep a Changelog 1.1.0*. https://keepachangelog.com/en/1.1.0/
- lucidrains. *x-transformers*, README. https://github.com/lucidrains/x-transformers
- Mineault, Patrick. *The Good Research Code Handbook: setup*. https://goodresearch.dev/setup
- Nygard, Michael. *Documenting Architecture Decisions*. 2011.
  https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions
- Papers with Code. *Releasing research code*. https://github.com/paperswithcode/releasing-research-code
- Paul, Ryan. *How Stripe builds interactive docs with Markdoc*. 2022. https://stripe.com/blog/markdoc
- Procida, Daniele. *Diátaxis*: start here, how to use Diátaxis. https://diataxis.fr/ ,
  https://diataxis.fr/how-to-use-diataxis/
- PyPA. *src layout vs flat layout*. https://packaging.python.org/en/latest/discussions/src-layout-vs-flat-layout/
- Rust project. *RFC template* and process. https://github.com/rust-lang/rfcs/blob/master/0000-template.md
- Various. *READMEs* of jax, equinox, pydantic, polars, ruff, uv, httpx, fastapi, tailscale, sqlite, pinocchio and
  mujoco, compared for their first screen. GitHub, default branches.
- Winters, Titus, Tom Manshreck and Hyrum Wright. *Software Engineering at Google*, chapter 3. 2020. Readability
  figures read through Engineer's Codex (secondary)

## Agents

- agents.md. *AGENTS.md*. https://agents.md/
- Anthropic. *Best practices for Claude Code*. https://code.claude.com/docs/en/best-practices
- Anthropic. *Claude Code in large codebases*. https://code.claude.com/docs/en/large-codebases
- Anthropic. *Effective context engineering for AI agents*.
  https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- Anthropic. *How Claude remembers your project*. https://code.claude.com/docs/en/memory
- Büsing, Moriz. *Greppability* essay. 2024. Read through copies (secondary)
- Chatlatanagulchai, et al. *Agent READMEs*. arXiv 2511.12884, 2025. https://arxiv.org/abs/2511.12884 (secondary:
  figures from a search summary)
- Cursor. *Rules*. https://cursor.com/docs/context/rules
- Gloaguen, et al. *Evaluating AGENTS.md*. arXiv 2602.11988, 2026. https://arxiv.org/abs/2602.11988
- Howard, Jeremy. *llms.txt*. 2024. https://github.com/AnswerDotAI/llms-txt
- Lopopolo, Ryan. *Harness engineering*. OpenAI, 2026. https://openai.com/index/harness-engineering/ (secondary)
- McMillan. *Instruction adherence factorial study*. arXiv 2605.10039, 2026. https://arxiv.org/abs/2605.10039
- Nigh, Matt. *How to write a great agents.md: lessons from over 2,500 repositories*. GitHub Blog, 2025.
  https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/
- OpenAI. *Custom instructions with AGENTS.md* (Codex). https://learn.chatgpt.com/docs/agent-configuration/agents-md
- OpenAI Cookbook. *Using PLANS.md for multi-hour problem solving*.
  https://developers.openai.com/cookbook/articles/codex_exec_plans (secondary: read through search results)
- pawamoy. *mkdocs-llmstxt*. https://github.com/pawamoy/mkdocs-llmstxt
- Ronacher, Armin. *Agentic Coding Recommendations*. 2025. https://lucumr.pocoo.org/2025/6/12/agentic-coding/
- Various. *Agent files* on GitHub default branches: https://github.com/astral-sh/uv/blob/main/AGENTS.md ,
  https://github.com/astral-sh/ruff/blob/main/AGENTS.md (and its one-line `CLAUDE.md`),
  https://github.com/huggingface/transformers/blob/main/.ai/AGENTS.md , pytorch/pytorch `CLAUDE.md`, and the
  `AGENTS.md` of openai/openai-agents-python, vLLM and LeRobot
- Willison, Simon. *Vibe engineering*. 2025 (unverified)

## Design philosophy

- antirez. *Writing system software: code comments*. 2018. https://antirez.com/news/124
- Eilers, Søren. *A LEGO counting problem*. http://web.math.ku.dk/~eilers/lego.html (unverified: the page refused
  the connection)
- Fitzpatrick, Brad, and David Crawshaw. *An unlikely database migration*. Tailscale, 2021.
  https://tailscale.com/blog/an-unlikely-database-migration
- Gabriel, Richard P. *The Rise of Worse is Better*. 1991. https://dreamsongs.com/RiseOfWorseIsBetter.html
- Hickey, Rich. *Simple Made Easy*. Strange Loop, 2011. Transcript: https://github.com/matthiasn/talk-transcripts
- Kidger, Patrick. *Just know stuff*. 2023. https://kidger.site/thoughts/just-know-stuff/
- LEGO Group. *LEGO System in Play*. https://www.lego.com/en-us/history/articles/lego-system-in-play
- LEGO Group. *The stud and tube principle*: patent date and the count of six-brick combinations. lego.com
  (secondary: search-result snippets)
- McIlroy, M. D., E. N. Pinson and B. A. Tague. *Unix Time-Sharing System: Foreword*. Bell System Technical Journal,
  1978; with Peter H. Salus, *A Quarter Century of Unix*, 1994, and McIlroy on options as quoted by McGonigle, 2005.
  All via https://en.wikipedia.org/wiki/Unix_philosophy (secondary)
- McKinley, Dan. *Choose Boring Technology*. 2015. https://mcfunley.com/choose-boring-technology
- Ousterhout, John. *A Philosophy of Software Design*. 1st ed. 2018, 2nd ed. 2021. Summary of principles and red
  flags checked against a web copy, https://yingang.github.io/aposd-zh/en/summary.html (secondary for the text)
- Ousterhout, John, and Robert C. Martin. *aposd-vs-clean-code*. 2025.
  https://github.com/johnousterhout/aposd-vs-clean-code
- Pennarun, Avery. *The new internet* (2024) and *10000-times-faster* (2025). Tailscale.
  https://tailscale.com/blog/new-internet , https://tailscale.com/blog/10000-times-faster
- Rams, Dieter. *Ten principles for good design*. Vitsœ. https://www.vitsoe.com/us/about/good-design
- Redis. *MANIFESTO* and the design comment of `src/bio.c`. Commit `669b2b9b`. https://github.com/redis/redis
- SQLite. Source `src/btree.c` and `src/btreeInt.h`: design notes and a citation of Knuth. Commit `0e5046b3`.
  https://github.com/sqlite/sqlite

## Repositories audited

- BetterHuman, commit `f2f32b2`. `/home/rikhat.akizhanov/better/BetterHuman` , https://github.com/rihat99/better_human
- BetterHuman design digests of related libraries, untracked. `/home/rikhat.akizhanov/better/BetterHuman/references/design/`
- BetterRetarget, commit `161a182`. `/home/rikhat.akizhanov/better/tracking/BetterRetarget`
- BetterRobot, commit `20862fe`. `/home/rikhat.akizhanov/better/BetterRobot` , https://github.com/rihat99/BetterRobot
- BetterRobot design digests of related libraries (`drake.md`, `BEST_PRACTICES.md`), untracked.
  `/home/rikhat.akizhanov/better/BetterRobot/references/design/`
- BetterVideoReconstruction, commit `f77a962`, with local changes in the working tree.
  `/home/rikhat.akizhanov/better/BetterVideoReconstruction`
- Owner. Auto-memory notes, private and local. `~/.claude/projects/-home-rikhat-akizhanov-better/memory/`
- Owner. Global working rules. `~/.claude/CLAUDE.md`
- Owner. Skills `autoresearch` and `adversarial-review`. `~/.claude/skills/`
- Workspace agent file. `/home/rikhat.akizhanov/better/CLAUDE.md`
