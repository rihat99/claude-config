#!/usr/bin/env bash
# Install or refresh the shared Claude Code configuration on this machine.
# Idempotent: safe to run again at any time. Works on macOS and Linux, no sudo.
#
#   bash install.sh                 # everything: config links, tools, autoresearch
#   bash install.sh --no-tools      # only config links (fast)
#   bash install.sh --no-autoresearch
#
# What it does
#   ~/.claude/CLAUDE.md, statusline.sh, keybindings.json  -> symlinks into this repo
#   ~/.claude/settings.json                                -> claude/settings.json (+ settings.macos.json on a Mac) + model keys from claude/models.json
#   ~/.claude/skills/<name>                                -> symlinks into this repo
#   ~/.claude/agents/<name>.md                             -> claude/agents/*.md with the effort from claude/models.json filled in
#   ~/.local/bin/trash, ~/.trash/                          -> trash helper and folder (macOS: the Finder Trash)
#   ~/.tmux.conf                                           -> symlink
#   tools (user-local): uv + ~/.claude/venv, jq, tectonic, resvg, node (Linux), LibreOffice AppImage (Linux), Claude Code
#   autoresearch skill from github.com/ramazan793/autoresearch_skill (vendor/, hooks merged into settings.json),
#     plus our delegation rule from claude/autoresearch/delegation.md (bin/patch_autoresearch.py)
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CL="$HOME/.claude"
OS="$(uname -s)"; ARCH="$(uname -m)"
DO_TOOLS=1; DO_AUTORESEARCH=1
for a in "$@"; do
  case "$a" in
    --no-tools) DO_TOOLS=0 ;;
    --no-autoresearch) DO_AUTORESEARCH=0 ;;
    -h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print} NR>1 && !/^#/ {exit}' "$0"; exit 0 ;;
    *) echo "unknown flag $a (see --help)" >&2; exit 2 ;;
  esac
done
export PATH="$HOME/.local/bin:$PATH"
log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*"; }

HT="$HOME/.trash"   # on macOS this is the Finder Trash (Finder may empty it after 30 days)
mkdir -p "$CL/skills" "$CL/agents" "$HOME/.local/bin" "$HT"
STASH="$HT/claude-config-install-$(date +%Y%m%d-%H%M%S)"

# Move an existing path out of the way (into ~/.trash) unless it is already our symlink.
stash() {
  local p="$1"
  [ -e "$p" ] || [ -L "$p" ] || return 0
  if [ -L "$p" ]; then
    case "$(readlink "$p")" in "$REPO"/*) rm -f "$p"; return 0 ;; esac
  fi
  mkdir -p "$STASH"
  mv "$p" "$STASH/$(basename "$p")" || { warn "could not move $p aside; leaving it"; return 1; }
  note "old $(basename "$p") moved to $STASH/"
}
link() { # link SRC DST
  local src="$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then return 0; fi
  stash "$dst" || return 1
  ln -s "$src" "$dst"
  note "linked $dst"
}

# ---------------------------------------------------------------- shell PATH
log "PATH"
# .bashrc always; .zshrc only on macOS or when it already exists
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  case "$rc" in *.zshrc) [ "$OS" = "Darwin" ] || [ -f "$rc" ] || continue ;; esac
  [ -f "$rc" ] || touch "$rc"
  grep -Ev '^[[:space:]]*#' "$rc" 2>/dev/null | grep -qE '(\$HOME|~|'"$HOME"')/\.local/bin' || { printf '\n# claude-config\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"; note "added ~/.local/bin to PATH in $rc"; }
done

# ---------------------------------------------------------------- config files
log "Config files"
link "$REPO/claude/CLAUDE.md"        "$CL/CLAUDE.md"
link "$REPO/claude/statusline.sh"    "$CL/statusline.sh"
link "$REPO/claude/keybindings.json" "$CL/keybindings.json"
link "$REPO/tmux/tmux.conf"          "$HOME/.tmux.conf"
link "$REPO/bin/trash"               "$HOME/.local/bin/trash"
chmod +x "$REPO/claude/statusline.sh" "$REPO/bin/trash"

[ -f "$CL/settings.local.json" ] && { stash "$CL/settings.local.json"; note "settings.local.json retired (its rules live in settings.json now)"; }

# ---------------------------------------------------------------- skills and agents
log "Skills"
RETIRED_SKILLS="codex-adversary diataxis-docs sphinx-docs write-tests design-principles file-naming python-standards subagent-orchestration"
for s in $RETIRED_SKILLS; do [ -e "$CL/skills/$s" ] && stash "$CL/skills/$s"; done
for d in "$REPO"/claude/skills/*/; do
  n="$(basename "$d")"
  link "${d%/}" "$CL/skills/$n"
done
# drop symlinks that point into this repo but whose target is gone
for p in "$CL"/skills/*; do
  [ -L "$p" ] || continue
  case "$(readlink "$p")" in "$REPO"/*) [ -e "$p" ] || { rm -f "$p"; note "removed stale link $p"; } ;; esac
done

# ---------------------------------------------------------------- tools
dl() { curl -fsSL --retry 3 -o "$2" "$1"; }
if [ "$DO_TOOLS" = 1 ]; then
  log "Tools (user-local, no sudo)"

  if ! command -v uv >/dev/null 2>&1; then
    note "installing uv"
    curl -LsSf --max-time 60 https://astral.sh/uv/install.sh | UV_NO_MODIFY_PATH=1 sh >/dev/null 2>&1
    if ! command -v uv >/dev/null 2>&1; then
      # fallback: GitHub release binary (some hosts block astral.sh)
      case "$OS-$ARCH" in
        Linux-x86_64)  UVA=uv-x86_64-unknown-linux-gnu.tar.gz ;;
        Linux-aarch64) UVA=uv-aarch64-unknown-linux-gnu.tar.gz ;;
        Darwin-arm64)  UVA=uv-aarch64-apple-darwin.tar.gz ;;
        Darwin-x86_64) UVA=uv-x86_64-apple-darwin.tar.gz ;;
        *) UVA="" ;;
      esac
      TMP="$(mktemp -d)"
      [ -n "$UVA" ] && dl "https://github.com/astral-sh/uv/releases/latest/download/$UVA" "$TMP/uv.tgz" && tar -xzf "$TMP/uv.tgz" -C "$TMP" \
        && B="$(find "$TMP" -type f -name uv | head -1)" && [ -n "$B" ] && mv "$B" "$HOME/.local/bin/uv" && chmod +x "$HOME/.local/bin/uv"
      rm -rf "$TMP"
    fi
    command -v uv >/dev/null 2>&1 && note "installed uv" || warn "uv install failed"
  fi
  if command -v uv >/dev/null 2>&1; then
    [ -x "$CL/venv/bin/python" ] || { note "creating ~/.claude/venv"; uv venv -q "$CL/venv" || warn "venv creation failed"; }
    if [ -x "$CL/venv/bin/python" ]; then
      uv pip install -q --python "$CL/venv/bin/python" python-pptx pymupdf pillow numpy matplotlib >/dev/null 2>&1 && note "venv: python-pptx pymupdf pillow numpy matplotlib" || warn "venv package install failed"
      uv pip install -q --python "$CL/venv/bin/python" cairosvg >/dev/null 2>&1 && "$CL/venv/bin/python" -c "import cairosvg" >/dev/null 2>&1 && note "venv: cairosvg (SVG->PDF)" || note "cairosvg unavailable here (needs libcairo); PDF export of figures falls back to other tools"
    fi
  fi

  if ! command -v jq >/dev/null 2>&1; then
    case "$OS-$ARCH" in
      Linux-x86_64)  JQ=jq-linux-amd64 ;;
      Linux-aarch64) JQ=jq-linux-arm64 ;;
      Darwin-arm64)  JQ=jq-macos-arm64 ;;
      Darwin-x86_64) JQ=jq-macos-amd64 ;;
      *) JQ="" ;;
    esac
    TMP="$(mktemp -d)"
    [ -n "$JQ" ] && { dl "https://github.com/jqlang/jq/releases/latest/download/$JQ" "$TMP/jq" && chmod +x "$TMP/jq" && "$TMP/jq" --version >/dev/null 2>&1 && mv "$TMP/jq" "$HOME/.local/bin/jq" && note "installed jq" || warn "jq download failed"; }
    rm -rf "$TMP"
  fi

  tectonic_ok() { command -v tectonic >/dev/null 2>&1 && tectonic --version >/dev/null 2>&1; }
  if ! tectonic_ok; then
    note "installing tectonic (LaTeX)"
    # a binary that exists but cannot run (built against a newer glibc) is moved aside
    [ -f "$HOME/.local/bin/tectonic" ] && mv "$HOME/.local/bin/tectonic" "$HT/tectonic.broken.$(date +%s)"
    # the official installer serves a glibc build that needs glibc >= 2.36; on Linux use the static musl build
    [ "$OS" = "Darwin" ] && (cd "$HOME/.local/bin" && curl --proto '=https' --tlsv1.2 -fsSL --max-time 120 https://drop-sh.fullyjustified.net | sh >/dev/null 2>&1)
    if ! tectonic_ok; then
      case "$OS-$ARCH" in
        Linux-x86_64)  TT=x86_64-unknown-linux-musl ;;
        Linux-aarch64) TT=aarch64-unknown-linux-musl ;;
        Darwin-arm64)  TT=aarch64-apple-darwin ;;
        Darwin-x86_64) TT=x86_64-apple-darwin ;;
        *) TT="" ;;
      esac
      if [ -n "$TT" ]; then
        TURL="$(curl -fsSL --max-time 30 https://api.github.com/repos/tectonic-typesetting/tectonic/releases/tags/continuous 2>/dev/null | grep -o "https://[^\"]*tectonic-[^\"]*-$TT.tar.gz" | head -1)"
        [ -n "$TURL" ] || TURL="https://github.com/tectonic-typesetting/tectonic/releases/download/continuous/tectonic-0.17.0+20260731-$TT.tar.gz"
        TMP="$(mktemp -d)"
        dl "$TURL" "$TMP/t.tgz" && tar -xzf "$TMP/t.tgz" -C "$TMP" && B="$(find "$TMP" -type f -name tectonic | head -1)" \
          && [ -n "$B" ] && mv "$B" "$HOME/.local/bin/tectonic" && chmod +x "$HOME/.local/bin/tectonic"
        rm -rf "$TMP"
      fi
    fi
    tectonic_ok && note "installed $(tectonic --version 2>/dev/null | head -1)" || warn "tectonic install failed"
  fi

  if ! command -v resvg >/dev/null 2>&1; then
    TMP="$(mktemp -d)"
    case "$OS-$ARCH" in
      Linux-x86_64)  dl https://github.com/linebender/resvg/releases/latest/download/resvg-linux-x86_64.tar.gz "$TMP/r.tgz" && tar -xzf "$TMP/r.tgz" -C "$TMP" ;;
      Darwin-arm64)  dl https://github.com/linebender/resvg/releases/latest/download/resvg-macos-aarch64.zip "$TMP/r.zip" && unzip -q "$TMP/r.zip" -d "$TMP" ;;
      Darwin-x86_64) dl https://github.com/linebender/resvg/releases/latest/download/resvg-macos-x86_64.zip "$TMP/r.zip" && unzip -q "$TMP/r.zip" -d "$TMP" ;;
    esac
    B="$(find "$TMP" -type f -name resvg | head -1)"
    [ -n "$B" ] && { mv "$B" "$HOME/.local/bin/resvg" && chmod +x "$HOME/.local/bin/resvg" && note "installed resvg (SVG->PNG)"; } || warn "resvg not installed for $OS-$ARCH"
    rm -rf "$TMP"
  fi

  if [ "$OS" = "Linux" ] && ! command -v node >/dev/null 2>&1; then
    NODE_V=v24.21.0
    case "$ARCH" in x86_64) NA=x64 ;; aarch64) NA=arm64 ;; *) NA="" ;; esac
    if [ -n "$NA" ]; then
      note "installing node $NODE_V"
      TMP="$(mktemp -d)"
      if dl "https://nodejs.org/dist/$NODE_V/node-$NODE_V-linux-$NA.tar.xz" "$TMP/node.tar.xz"; then
        mkdir -p "$HOME/.local/node" && tar -xJf "$TMP/node.tar.xz" -C "$HOME/.local/node" --strip-components=1 \
          && for b in node npm npx; do ln -sf "$HOME/.local/node/bin/$b" "$HOME/.local/bin/$b"; done && note "installed node"
      else warn "node download failed"; fi
      rm -rf "$TMP"
    fi
  fi

  if [ "$OS" = "Linux" ] && ! command -v soffice >/dev/null 2>&1 && ! command -v libreoffice >/dev/null 2>&1; then
    if [ "$ARCH" = "x86_64" ]; then
      note "installing LibreOffice (~300 MB, for slide previews)"
      mkdir -p "$HOME/.local/libreoffice"
      LO_OK=""
      if dl "https://appimages.libreitalia.org/LibreOffice-fresh.basic-x86_64.AppImage" "$HOME/.local/libreoffice/LibreOffice.AppImage"; then
        chmod +x "$HOME/.local/libreoffice/LibreOffice.AppImage"
        (cd "$HOME/.local/libreoffice" && ./LibreOffice.AppImage --appimage-extract >/dev/null 2>&1) \
          && ln -sf "$HOME/.local/libreoffice/squashfs-root/AppRun" "$HOME/.local/bin/soffice" && LO_OK=1
        rm -f "$HOME/.local/libreoffice/LibreOffice.AppImage"
      fi
      if [ -z "$LO_OK" ] && command -v dpkg-deb >/dev/null 2>&1; then
        # fallback: official .deb tarball, extracted per user (no root)
        LO_V="$(curl -fsSL --max-time 30 https://download.documentfoundation.org/libreoffice/stable/ | grep -o -E '[0-9]+\.[0-9]+\.[0-9]+' | sort -V | uniq | tail -1)"
        TMP="$(mktemp -d)"
        if [ -n "$LO_V" ] && dl "https://download.documentfoundation.org/libreoffice/stable/$LO_V/deb/x86_64/LibreOffice_${LO_V}_Linux_x86-64_deb.tar.gz" "$TMP/lo.tgz"; then
          tar -xzf "$TMP/lo.tgz" -C "$TMP" && for d in "$TMP"/*/DEBS/*.deb; do dpkg-deb -x "$d" "$HOME/.local/libreoffice"; done
          SOFF="$(ls -d "$HOME"/.local/libreoffice/opt/libreoffice*/program/soffice 2>/dev/null | head -1)"
          [ -n "$SOFF" ] && ln -sf "$SOFF" "$HOME/.local/bin/soffice" && LO_OK=1
        fi
        rm -rf "$TMP"
      fi
      [ -n "$LO_OK" ] && note "installed soffice" || warn "LibreOffice install failed (slides cannot be previewed here)"
    fi
  fi

  if ! command -v claude >/dev/null 2>&1; then
    note "installing Claude Code"
    curl -fsSL https://claude.ai/install.sh | bash >/dev/null 2>&1 && note "installed Claude Code (run 'claude' once to log in)" || warn "Claude Code install failed"
  else
    # a stale CLI silently maps the model aliases to older models (and rejects pinned new ids)
    claude update >/dev/null 2>&1 && note "Claude Code $(claude --version 2>/dev/null | cut -d' ' -f1)" || warn "claude update failed (offline?)"
  fi
fi

# ---------------------------------------------------------------- autoresearch
if [ "$DO_AUTORESEARCH" = 1 ]; then
  log "Autoresearch skill"
  # The upstream repo is private. The Mac clones/updates it; sync.sh copies vendor/ to the other machines.
  mkdir -p "$REPO/vendor"
  if [ -d "$REPO/vendor/autoresearch_skill/.git" ]; then
    [ "$OS" = "Darwin" ] && { git -C "$REPO/vendor/autoresearch_skill" pull -q --ff-only 2>/dev/null || warn "could not update autoresearch (offline or no GitHub access)"; }
  else
    GIT_TERMINAL_PROMPT=0 git clone -q https://github.com/ramazan793/autoresearch_skill.git "$REPO/vendor/autoresearch_skill" 2>/dev/null \
      || warn "could not clone autoresearch (private repo; run sync.sh from the Mac to copy it)"
  fi
  if [ -f "$REPO/vendor/autoresearch_skill/install.sh" ]; then
    # their installer refuses a symlinked skill dir only if it is ours; it writes into ~/.claude/skills/autoresearch
    [ -L "$CL/skills/autoresearch" ] && rm -f "$CL/skills/autoresearch"
    bash "$REPO/vendor/autoresearch_skill/install.sh" >/dev/null 2>&1 && note "autoresearch installed (skill, hooks, mars_* agents)" || warn "autoresearch installer reported a problem"
    # our delegation rule goes into the freshly copied SKILL.md and playbook (upstream text untouched)
    python3 "$REPO/bin/patch_autoresearch.py" || warn "patch_autoresearch.py failed"
    # their installer backs settings.json up next to it; keep ~/.claude tidy
    for b in "$CL"/settings.json.bak.*; do [ -e "$b" ] && mv "$b" "$HT/" 2>/dev/null; done
    [ -f "$HOME/.config/autoresearch/telegram.env" ] && grep -q 'TG_BOT_TOKEN=$\|TG_BOT_TOKEN=""\|<' "$HOME/.config/autoresearch/telegram.env" 2>/dev/null && note "Telegram not configured: edit ~/.config/autoresearch/telegram.env"
  fi
fi

# ---------------------------------------------------------------- settings.json and agents
# After autoresearch on purpose: its installer copies mars_*.md into ~/.claude/agents and merges its
# hooks into settings.json; render_config.py then writes our versions (model tiers from claude/models.json).
log "settings.json and agents (claude/models.json)"
python3 "$REPO/bin/render_config.py" || warn "render_config.py failed"

# ---------------------------------------------------------------- git identity
if command -v git >/dev/null 2>&1 && [ -z "$(git config --global user.email 2>/dev/null)" ]; then
  git config --global user.name "rihat99"; git config --global user.email "mr.rihat@gmail.com"
  note "set git identity (rihat99 <mr.rihat@gmail.com>)"
fi

# ---------------------------------------------------------------- summary
log "Summary on $(hostname) ($OS $ARCH)"
have() {  # found and runs (answers --version, -V or --help)
  if ! command -v "$1" >/dev/null 2>&1; then printf '  %-12s MISSING\n' "$1"; return; fi
  for flag in --version -V --help; do
    perl -e 'alarm 30; exec @ARGV' "$1" "$flag" >/dev/null 2>&1 && { printf '  %-12s %s\n' "$1" "$(command -v "$1")"; return; }
  done
  printf '  %-12s BROKEN (%s)\n' "$1" "$(command -v "$1")"
}
have claude; have tmux; have jq; have uv; have tectonic; have resvg; have node; have trash
if [ "$OS" = "Darwin" ]; then
  [ -d "/Applications/Microsoft PowerPoint.app" ] && printf '  %-12s %s\n' powerpoint "/Applications/Microsoft PowerPoint.app" || printf '  %-12s MISSING\n' powerpoint
else
  have soffice
fi
[ -x "$CL/venv/bin/python" ] && printf '  %-12s %s\n' venv "$CL/venv" || printf '  %-12s MISSING\n' venv
printf '  %-12s %s\n' skills "$(ls "$CL/skills" | grep -v synced | tr '\n' ' ')"
printf '  %-12s %s\n' agents "$(ls "$CL/agents" | sed 's/\.md$//' | tr '\n' ' ')"
[ -d "$STASH" ] && note "replaced files are in $STASH"
echo "done."
