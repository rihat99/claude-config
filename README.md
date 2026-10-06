# claude-config

One Claude Code setup for every machine: Mac, rikhat_ws, robotics1, robotics2, robotics3, robomed4.

```
claude/CLAUDE.md          global rules (how to think, write, ask, delete, code, delegate)
claude/settings.json      model, effort, permissions (auto mode + allow/ask/deny), status line
claude/settings.macos.json  extras only for the Mac (draw.io plugin)
claude/statusline.sh      status bar: [Model · effort] ctx % tokens │ 5h % │ 7d %
claude/keybindings.json   keyboard shortcuts
claude/agents/            pinned subagents: worker (Opus xhigh), light (Sonnet), adversary (Opus max, read-only)
claude/skills/            adversarial-review, explain-html, figure, latex-report, slides, cpp-standards, archify (vendored)
bin/trash                 move files to <repo>/trash/ or ~/.trash/ instead of rm
tmux/tmux.conf            shared tmux config
install.sh                link everything into ~/.claude, install user-local tools, install autoresearch
sync.sh                   rsync this repo to the other machines and run install.sh there
cleanup.sh                delete chats/caches older than 30 days, trash old handoffs/jobs/backups
vendor/                   (gitignored) autoresearch_skill clone; the upstream repo is private, so the Mac clones it and sync.sh copies it along
```

## Daily use

Edit a file here, then:

```bash
cd ~/claude-config && git commit -am "what changed" && git push     # history on GitHub
bash sync.sh                                                         # push to every machine
```

`install.sh` symlinks CLAUDE.md, skills, agents, statusline and tmux.conf into `~/.claude`, so on the Mac an edit here is live immediately. `settings.json` is copied (Claude Code rewrites it), so run `bash install.sh --no-tools` after changing it.

The other machines have no GitHub credentials; `sync.sh` copies the repo (with its `.git`) over SSH. If you edit on a remote machine, copy the change back here.

## What is per machine

- **Login**: run `claude` once on a new machine and log in.
- **Telegram for autoresearch**: `~/.config/autoresearch/telegram.env` (bot token + chat id). Not synced.
- **Tools** are installed per user by `install.sh`: `uv` and `~/.claude/venv` (python-pptx, pymupdf, matplotlib), `jq`, `tectonic` (LaTeX), `resvg` (SVG→PNG), `node` (Linux), LibreOffice AppImage (Linux, slide previews). On the Mac slides render through PowerPoint.

## Deleting

Claude never runs `rm`; it runs `trash <paths>`. Inside a git repo that lands in `<repo>/trash/` (gitignored), elsewhere in `~/.trash/`. Empty them yourself when you want the space back.

On the Mac the filesystem ignores case, so `~/.trash` *is* the system `~/.Trash`: trashed files show up in the Finder's Trash and you empty it from the Dock. Claude cannot list that folder (macOS protects it), which is fine.

## Cleanup of old state

```bash
bash cleanup.sh          # dry run
bash cleanup.sh --yes    # apply
```

There is no automatic cleanup beyond Claude Code's own 30-day default.
