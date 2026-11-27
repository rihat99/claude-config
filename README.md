# claude-config

My Claude Code setup, kept in one place and copied to every machine I work on: the Mac, rikhat_ws, robotics1, robotics2, robotics3 and robomed4. Claude follows the same rules, has the same skills and asks for the same permissions wherever I open it.

## What it gives me

- **One set of working rules.** [`claude/CLAUDE.md`](claude/CLAUDE.md) tells Claude how to think before coding, keep changes small, ask before deciding things that are mine to decide, and write replies I can read on a phone.
- **Skills for the work I repeat.** Coding to my principles, debugging, reviews, figures, reports, slides, paper explainers.
- **Fixed models.** `opus` means the same version on every machine, and helper agents run on a tier I chose.
- **Fewer permission prompts, safely.** Everyday commands run without asking. Deleting asks first. `sudo` and force-push are blocked.
- **Nothing is deleted.** Claude moves files to a trash folder with `trash` and never runs `rm` on its own.

## Set it up

On the Mac (the machine that holds the GitHub login):

```bash
git clone git@github.com:rihat99/claude-config.git ~/claude-config
cd ~/claude-config && bash install.sh
```

Every other machine gets it from the Mac, since they have no GitHub login:

```bash
bash sync.sh                 # all machines
bash sync.sh robotics3       # one machine
```

Then run `claude` once on a new machine and log in. `install.sh` is safe to run again at any time and needs no `sudo`.

## Change something

Edit a file here, then:

```bash
cd ~/claude-config
bash install.sh --no-tools                        # apply on this machine (seconds)
git commit -am "what changed" && git push         # keep the history
bash sync.sh --no-tools                           # send it to the other machines
```

`CLAUDE.md`, the skills, the status line and `tmux.conf` are links into this folder, so on the Mac an edit is live at once. `settings.json` and the agents are written out by `install.sh`, so they need the first command. A Claude session that is already open picks up new settings after a restart.

`sync.sh` skips a machine whose copy has its own edits or commits, so nothing is lost; bring those changes back here first, or pass `--force` to overwrite them.

## The skills

A skill is a set of instructions Claude loads only when the task calls for it.

| Skill | Claude uses it when I ask for |
|---|---|
| `code` | any real code change or code review. It carries my ten laws, twelve chapters of principles (architecture, API design, naming, code, determinism and performance, testing, docs, releases, repository layout, agent files, review, applications) and the C++/CUDA rules. |
| `debugging` | something is broken and the cause is unknown: a bug, a flaky test, NaN, a CUDA error, a slowdown. |
| `adversarial-review` | a second opinion on important code, numbers or conclusions, from a fresh agent that only reads. |
| `figure` | a static figure or schematic as SVG. |
| `latex-report` | a PDF report or paper draft. |
| `slides` | a slide deck (.pptx). |
| `explain-html` | a web page that explains something. |
| `archify` | an interactive HTML diagram of a system (vendored from its upstream). |
| `better-paper` | explainer pages for research papers. Lives in its own repo, see below. |
| `autoresearch` | an autonomous research run. Installed from a colleague's private repo, with one local addition. |

The principle chapters live in [`claude/skills/code/references/`](claude/skills/code/references/). This is their home: edit them here. Ideas borrowed from other people's skills (ponytail, mattpocock/skills, superpowers) are in `code/SKILL.md` and `debugging/SKILL.md`; the chapters are mine.

## The helper agents

Claude can hand part of a task to a helper with a clean context. The pinned ones:

| Agent | Model tier | For |
|---|---|---|
| `worker` | opus | real subtasks: design, tricky code, experiments. It cannot start helpers of its own. |
| `light` | sonnet | mechanical work: searching, summarising, converting. |
| `adversary` | opus, maximum effort, read-only | independent criticism. |
| `mars_*` | mixed | only inside `autoresearch`. |

## Models

[`claude/models.json`](claude/models.json) is the one place where model versions live:

```json
{
  "fable":  { "id": "claude-fable-5-1",  "effort": "medium" },
  "opus":   { "id": "claude-opus-5-5",   "effort": "xhigh" },
  "sonnet": { "id": "claude-sonnet-5-5", "effort": "xhigh" },
  "session":   "opus[1m]",
  "subagents": "opus"
}
```

`session` is the model a terminal session starts on, `subagents` the tier a helper gets when nothing else picks one. To move to a new version, change the `id` and run the three commands from "Change something".

Why pin: without it the same alias resolved to different versions on different machines. A Claude Code too old for a pinned id fails with `API Error: 400 ... does not support this model`; run `claude update` there. The desktop app ignores these defaults and uses its own model picker.

## What Claude may do without asking

Set in [`claude/settings.json`](claude/settings.json):

- **Runs freely**: reading and searching files, copying and moving, Python tooling (`uv`, `pytest`, `ruff`), LaTeX, every `git` command except force-push, `kill` and `pkill`.
- **Asks first**: `rm`, `rmdir`, `find -delete`, `killall`, `rsync --delete`, `tmux kill-*`.
- **Blocked**: `sudo`, `dd`, `mkfs`, recursive `chmod`/`chown`, `git push --force`, reading `.env` files and SSH or AWS keys.

Anything not listed goes through Claude Code's auto mode, which judges each command. Other choices in that file: updates follow the `stable` channel, and chat transcripts are kept 90 days.

## Deleting

Claude runs `trash <paths>` where it would run `rm`. Inside a git repo the files land in that repo's `trash/` folder, elsewhere in `~/.trash/`. Nothing in the trash is overwritten; an older item with the same name gets a timestamp. I empty the trash myself.

On the Mac `~/.trash` is the Finder Trash, which Finder empties after 30 days. A path on a different disk than its trash folder is refused, because moving it would copy everything; Claude then asks for `rm`, or I set `TRASH_DIR` to a folder on that disk.

## What differs per machine

- **Login**: once per machine.
- **Telegram for autoresearch**: `~/.config/autoresearch/telegram.env`, entered by hand, never synced.
- **Tools**: `install.sh` installs what the skills need for the current user: `uv` and a small Python environment, `jq`, `tectonic` (LaTeX), `resvg` (SVG to PNG), `node` and LibreOffice on Linux. On the Mac slides render through PowerPoint. Web pages are screenshotted only where Chrome exists: the Mac, rikhat_ws and robotics1.
- **Mac only**: the draw.io plugin (`claude/settings.macos.json`).

## The better-paper skill

It has its own repo, `~/Desktop/projects/BetterPaper` (GitHub: rihat99/BetterPaper). To ship a change:

```bash
cd ~/Desktop/projects/BetterPaper && git commit -am "what changed" && git push
cd ~/claude-config && bash install.sh --no-tools && bash sync.sh --no-tools
```

## Housekeeping

```bash
bash cleanup.sh          # show leftovers: old handoffs, downloads, *.bak files
bash cleanup.sh --yes    # move them to the trash
```

It only moves things to the trash and never touches chats.

## Where things are

| Path | What it is |
|---|---|
| `claude/CLAUDE.md` | the global working rules |
| `claude/settings.json` | permissions and other Claude Code settings; `settings.macos.json` adds the Mac-only part |
| `claude/models.json` | model versions and effort per tier |
| `claude/agents/` | the helper agents |
| `claude/skills/` | the skills kept in this repo |
| `claude/autoresearch/delegation.md` | my addition to the autoresearch skill: the orchestrator hands shell and multi-file work to helpers |
| `claude/statusline.sh` | the status bar: model, context used, 5-hour and 7-day usage |
| `claude/keybindings.json` | keyboard shortcuts |
| `tmux/tmux.conf` | shared tmux config |
| `bin/trash` | the trash helper |
| `bin/render_config.py` | writes `~/.claude/settings.json` and the agents from the files above |
| `bin/patch_autoresearch.py` | inserts `delegation.md` into the installed autoresearch skill |
| `install.sh`, `sync.sh`, `cleanup.sh` | set up this machine, copy to the others, tidy up |
| `vendor/` | not in git: the autoresearch and BetterPaper clones, copied along by `sync.sh` |
