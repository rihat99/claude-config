# claude-config

One Claude Code setup for every machine: Mac, rikhat_ws, robotics1, robotics2, robotics3, robomed4.

```
claude/CLAUDE.md          global rules (how to think, write, ask, delete, code, delegate)
claude/models.json        the three model tiers (fable / opus / sonnet): exact version + effort, session default, subagent default
claude/settings.json      permissions (auto mode + allow/ask/deny), status line, env; model keys are added from models.json
claude/settings.macos.json  extras only for the Mac (draw.io plugin)
claude/statusline.sh      status bar: [Model · effort] ctx % tokens │ 5h % │ 7d %
claude/keybindings.json   keyboard shortcuts
claude/agents/            pinned subagents: worker (opus), light (sonnet), adversary (opus, max, read-only), mars_* (our copies: mars_top inherits the session model, mars_top_opus/mars_aux opus, mars_light sonnet)
claude/autoresearch/      delegation.md: our rule that the autoresearch orchestrator hands shell and multi-file work to subagents
claude/skills/            adversarial-review, explain-html, figure, latex-report, slides, cpp-standards, archify (vendored)
bin/trash                 move files to <repo>/trash/ or ~/.trash/ instead of rm
bin/render_config.py      writes ~/.claude/settings.json and ~/.claude/agents/*.md from the files above (run by install.sh)
bin/patch_autoresearch.py inserts claude/autoresearch/delegation.md into the installed autoresearch SKILL.md and playbook (run by install.sh; upstream text untouched)
tmux/tmux.conf            shared tmux config
install.sh                link everything into ~/.claude, install user-local tools (and update Claude Code), install autoresearch
sync.sh                   rsync this repo to the other machines (skips a host with its own edits) and run install.sh there
cleanup.sh                move leftovers (handoffs, downloads, backup files) to the trash; never deletes
vendor/                   (gitignored) autoresearch_skill clone; the upstream repo is private, so the Mac clones it and sync.sh copies it along
vendor/BetterPaper/       (gitignored) the better-paper skill (paper explainer pages), cloned from github.com/rihat99/BetterPaper and linked as ~/.claude/skills/better-paper
```

## Daily use

Edit a file here, then:

```bash
cd ~/claude-config && git commit -am "what changed" && git push     # history on GitHub
bash sync.sh                                                         # push to every machine
```

`install.sh` symlinks CLAUDE.md, skills, statusline and tmux.conf into `~/.claude`, so on the Mac an edit here is live immediately. `settings.json` and the agents are *written* (settings.json because Claude Code rewrites it, agents because their effort comes from models.json), so run `bash install.sh --no-tools` after changing `settings.json`, `models.json` or anything in `agents/`.

## The better-paper skill

It lives in its own repo, `~/Desktop/projects/BetterPaper` on the Mac (GitHub: rihat99/BetterPaper). To ship a change:

```bash
cd ~/Desktop/projects/BetterPaper && git commit -am "what changed" && git push
cd ~/claude-config && bash install.sh --no-tools && bash sync.sh --no-tools    # the Mac pulls it into vendor/, sync copies it on
```

## Models

`claude/models.json`:

```json
{
  "fable":  { "id": "claude-fable-5-1",  "effort": "medium" },
  "opus":   { "id": "claude-opus-5-5",   "effort": "xhigh" },
  "sonnet": { "id": "claude-sonnet-5-5", "effort": "xhigh" },
  "session":   "opus[1m]",
  "subagents": "opus"
}
```

The aliases `fable`, `opus`, `sonnet` are pinned to these ids on every machine (`ANTHROPIC_DEFAULT_*_MODEL` in the settings env), so `/model opus` or `model: opus` in an agent always means the same version. Without the pin the alias can differ per machine (robotics2 resolved `opus` to Opus 5 while the Mac got Opus 5.5, on the same account). `subagents` sets `CLAUDE_CODE_SUBAGENT_MODEL`: any agent without a model of its own runs there, whatever the session model is. The built-in Plan agent always inherits the session model.

New model version: change the `id` (and effort if you like), then

```bash
bash install.sh --no-tools && git commit -am "models: ..." && git push && bash sync.sh --no-tools
```

A Claude Code that is too old for the pinned id fails loudly (`API Error: 400 ... does not support this model`), which is the point: run `claude update` there.

The Claude desktop app ignores these defaults: it starts every session with its own `--model` and `--effort` flags from its picker. The settings govern terminal sessions (and all remote machines).

The other machines have no GitHub credentials; `sync.sh` copies the repo (with its `.git`) over SSH and overwrites the remote copy. It refuses a host whose copy has uncommitted edits or its own commits, so nothing is lost silently: copy those changes back here first, or pass `--force`. A remote `~/claude-config/trash/` is never touched. `install.sh` also sets the git identity when none is set, retires `~/.claude/settings.local.json` (its rules live in settings.json), and with tools enabled runs `claude update`.

## What is per machine

- **Login**: run `claude` once on a new machine and log in.
- **Telegram for autoresearch**: `~/.config/autoresearch/telegram.env` (bot token + chat id). Not synced.
- **Tools** are installed per user by `install.sh`: `uv` and `~/.claude/venv` (python-pptx, pymupdf, matplotlib), `jq`, `tectonic` (LaTeX; the static musl build on Linux, the official one needs a newer glibc than Ubuntu 22.04 has), `resvg` (SVG→PNG), `node` (Linux), LibreOffice AppImage (Linux, slide previews). On the Mac slides render through PowerPoint. Web pages (explain-html, archify) need Chrome: present on the Mac, rikhat_ws and robotics1; robotics2/3 and robomed4 lack it and the system libraries it needs, so pages built there are not screenshotted.

## Deleting

Claude never runs `rm`; it runs `trash <paths>`. Inside a git repo that lands in `<main checkout>/trash/` (gitignored; a linked worktree uses the main checkout's folder so `git worktree remove` cannot delete it), elsewhere in `~/.trash/`. Nothing is overwritten: an older item with the same name gets a timestamp. A path on another filesystem than its trash folder (for example `/data1/...` outside a repo on the GPU servers) is refused, because moving it would copy everything; Claude then asks for `rm`, or you set `TRASH_DIR` to a folder on that disk. Empty the trash folders yourself when you want the space back.

On the Mac the filesystem ignores case, so `~/.trash` *is* the system `~/.Trash`: trashed files show up in the Finder's Trash and you empty it from the Dock. Finder is set to remove items after 30 days, which also applies to the installer's settings backups that land there. Claude cannot list that folder (macOS protects it), which is fine.

## Cleanup of old state

```bash
bash cleanup.sh          # dry run
bash cleanup.sh --yes    # apply
```

It only moves leftovers (old handoffs, downloads, `*.bak*` files) into the trash. Chats are not touched: Claude Code removes terminal transcripts older than 30 days by itself and keeps Desktop-app sessions until you archive them in the app. There is no automatic cleanup beyond that.
