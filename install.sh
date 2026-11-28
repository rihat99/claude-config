#!/usr/bin/env bash
# Install or refresh my setup on this machine: the Claude Code configuration, and two optional
# parts for the terminal. Idempotent: safe to run again at any time. macOS and Linux, no sudo.
#
#   bash install.sh                 # everything: config links and tools
#   bash install.sh --no-tools      # only config links (fast)
#   bash install.sh --shell         # switch the shell part on here, or update it
#   bash install.sh --tmux          # switch the tmux part on here, or update it
#   bash install.sh --no-shell      # switch a part off again (same for --no-tmux)
#
# A part that was switched on stays on: the machine remembers it in ~/.config/dotfiles/parts,
# so later plain runs and sync.sh keep it. Downloads happen only on a run that passes the flag.
#
# What it does
#   ~/.claude/CLAUDE.md, statusline.sh, keybindings.json  -> symlinks into this repo
#   ~/.claude/settings.json                                -> claude/settings.json (+ settings.macos.json on a Mac) + model keys from claude/models.json;
#                                                             its hooks run files of the self-compact and autoresearch skills
#   ~/.claude/skills/<name>                                -> symlinks into this repo
#   ~/.claude/agents/<name>.md                             -> claude/agents/*.md with the effort from claude/models.json filled in
#   ~/.local/bin/trash, ~/.trash/                          -> trash helper and folder (macOS: the Finder Trash)
#   ~/.tmux.conf                                           -> tmux/tmux.conf
#   shell part: oh-my-zsh (macOS) or oh-my-bash (Linux) in ~/.oh-my-*, starship in ~/.local/bin,
#               and one block in ~/.zshrc or ~/.bashrc that sources shell/zshrc.zsh or shell/bashrc.bash
#   tmux part:  Oh my tmux in ~/.local/share/oh-my-tmux; ~/.tmux.conf -> its .tmux.conf,
#               ~/.tmux.conf.local -> tmux/tmux.conf.local (my keys and settings)
#   tools (user-local): uv + ~/.claude/venv, jq, tectonic, resvg, node (Linux), LibreOffice AppImage (Linux), Claude Code
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CL="$HOME/.claude"
OS="$(uname -s)"; ARCH="$(uname -m)"
DO_TOOLS=1
SHELL_FLAG=""; TMUX_FLAG=""   # on | off | "" (keep what this machine remembers)
for a in "$@"; do
  case "$a" in
    --no-tools) DO_TOOLS=0 ;;
    --shell) SHELL_FLAG=on ;;
    --no-shell) SHELL_FLAG=off ;;
    --tmux) TMUX_FLAG=on ;;
    --no-tmux) TMUX_FLAG=off ;;
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
STASH="$HT/dotfiles-install-$(date +%Y%m%d-%H%M%S)"
OMT="$HOME/.local/share/oh-my-tmux"

# Optional parts this machine has switched on, one name per line.
PARTS_FILE="$HOME/.config/dotfiles/parts"
part_on() { grep -qx "$1" "$PARTS_FILE" 2>/dev/null; }
set_part() { # set_part NAME on|off
  mkdir -p "$(dirname "$PARTS_FILE")"
  local rest; rest="$(grep -vx "$1" "$PARTS_FILE" 2>/dev/null)"
  { [ -n "$rest" ] && printf '%s\n' "$rest"; [ "$2" = on ] && printf '%s\n' "$1"; } > "$PARTS_FILE"
}
[ -n "$SHELL_FLAG" ] && set_part shell "$SHELL_FLAG"
[ -n "$TMUX_FLAG" ] && set_part tmux "$TMUX_FLAG"

# Clone a public repo once; pull it only on a run that passed the part's flag.
fetch_repo() { # fetch_repo URL DIR FLAG
  local url="$1" dir="$2" flag="$3"
  if [ ! -d "$dir/.git" ]; then
    git clone -q --depth 1 "$url" "$dir" && note "cloned $url" || { warn "could not clone $url"; return 1; }
  elif [ "$flag" = on ]; then
    git -C "$dir" pull -q --ff-only && note "updated $dir" || warn "could not update $dir"
  fi
}

# Move an existing path out of the way (into ~/.trash) unless it is already our symlink.
stash() {
  local p="$1"
  [ -e "$p" ] || [ -L "$p" ] || return 0
  if [ -L "$p" ]; then
    case "$(readlink "$p")" in "$REPO"/*|"$OMT"/*) rm -f "$p"; return 0 ;; esac
  fi
  mkdir -p "$STASH"
  mv "$p" "$STASH/$(basename "$p")" || { warn "could not move $p aside; leaving it"; return 1; }
  note "old $(basename "$p") moved to $STASH/"
}
dl() { curl -fsSL --retry 3 -o "$2" "$1"; }
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
  grep -Ev '^[[:space:]]*#' "$rc" 2>/dev/null | grep -qE '(\$HOME|~|'"$HOME"')/\.local/bin' || { printf '\n# dotfiles\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"; note "added ~/.local/bin to PATH in $rc"; }
done

# ---------------------------------------------------------------- config files
log "Config files"
link "$REPO/claude/CLAUDE.md"        "$CL/CLAUDE.md"
link "$REPO/claude/statusline.sh"    "$CL/statusline.sh"
link "$REPO/claude/keybindings.json" "$CL/keybindings.json"
link "$REPO/bin/trash"               "$HOME/.local/bin/trash"
chmod +x "$REPO/claude/statusline.sh" "$REPO/bin/trash"

[ -f "$CL/settings.local.json" ] && { stash "$CL/settings.local.json"; note "settings.local.json retired (its rules live in settings.json now)"; }

# ---------------------------------------------------------------- tmux
if part_on tmux && fetch_repo https://github.com/gpakosz/.tmux.git "$OMT" "$TMUX_FLAG"; then
  log "tmux (Oh my tmux)"
  link "$OMT/.tmux.conf"            "$HOME/.tmux.conf"
  link "$REPO/tmux/tmux.conf.local" "$HOME/.tmux.conf.local"
else
  link "$REPO/tmux/tmux.conf" "$HOME/.tmux.conf"
  [ -L "$HOME/.tmux.conf.local" ] && stash "$HOME/.tmux.conf.local"
fi
[ -n "$TMUX_FLAG" ] && note "tmux part $TMUX_FLAG; a running tmux picks it up after: tmux kill-server (or <prefix> r)"

# ---------------------------------------------------------------- shell (oh-my-zsh / oh-my-bash + starship)
# zsh on macOS, bash on Linux: the login shell on each kind of machine
if [ "$OS" = "Darwin" ]; then SHELL_RC="$HOME/.zshrc"; SHELL_SRC="$REPO/shell/zshrc.zsh"
else SHELL_RC="$HOME/.bashrc"; SHELL_SRC="$REPO/shell/bashrc.bash"; fi
RC_BEGIN="# >>> dotfiles shell >>>"; RC_END="# <<< dotfiles shell <<<"
drop_rc_block() {
  grep -qxF "$RC_BEGIN" "$SHELL_RC" 2>/dev/null || return 0
  local tmp; tmp="$(mktemp)"
  awk -v b="$RC_BEGIN" -v e="$RC_END" '$0==b {skip=1} !skip {print} $0==e {skip=0}' "$SHELL_RC" > "$tmp" && cat "$tmp" > "$SHELL_RC"
  rm -f "$tmp"
}
install_starship() {
  local target tmp
  case "$OS-$ARCH" in
    Linux-x86_64)  target=x86_64-unknown-linux-musl ;;
    Linux-aarch64) target=aarch64-unknown-linux-musl ;;
    Darwin-arm64)  target=aarch64-apple-darwin ;;
    Darwin-x86_64) target=x86_64-apple-darwin ;;
    *) warn "no starship build for $OS-$ARCH"; return 1 ;;
  esac
  tmp="$(mktemp -d)"
  dl "https://github.com/starship/starship/releases/latest/download/starship-$target.tar.gz" "$tmp/s.tgz" \
    && tar -xzf "$tmp/s.tgz" -C "$tmp" && "$tmp/starship" --version >/dev/null 2>&1 \
    && mv "$tmp/starship" "$HOME/.local/bin/starship" && note "installed $("$HOME/.local/bin/starship" --version | head -1)" \
    || warn "starship install failed"
  rm -rf "$tmp"
}
if part_on shell; then
  log "Shell (starship prompt)"
  if [ "$OS" = "Darwin" ]; then
    fetch_repo https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh" "$SHELL_FLAG"
    for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
      fetch_repo "https://github.com/zsh-users/$plugin.git" "$HOME/.oh-my-zsh/custom/plugins/$plugin" "$SHELL_FLAG"
    done
  else
    fetch_repo https://github.com/ohmybash/oh-my-bash.git "$HOME/.oh-my-bash" "$SHELL_FLAG"
  fi
  { [ -x "$HOME/.local/bin/starship" ] && [ "$SHELL_FLAG" != on ]; } || install_starship
  if ! grep -qxF "$RC_BEGIN" "$SHELL_RC" 2>/dev/null; then
    printf '\n%s\n. "%s"\n%s\n' "$RC_BEGIN" "$SHELL_SRC" "$RC_END" >> "$SHELL_RC"
    note "added the dotfiles block to $SHELL_RC (open a new terminal to see it)"
  fi
elif [ "$SHELL_FLAG" = off ]; then
  drop_rc_block
  note "shell part off: block removed from $SHELL_RC; ~/.oh-my-zsh or ~/.oh-my-bash and starship stay on disk"
fi

# ---------------------------------------------------------------- skills and agents
log "Skills"
RETIRED_SKILLS="codex-adversary diataxis-docs sphinx-docs write-tests design-principles file-naming python-standards subagent-orchestration cpp-standards"
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

# ---------------------------------------------------------------- settings.json and agents
log "settings.json and agents (claude/models.json)"
python3 "$REPO/bin/render_config.py" || warn "render_config.py failed"
# a skill or agent with broken frontmatter is ignored silently by Claude Code; say so here instead
if command -v claude >/dev/null 2>&1; then
  # the skills are validated in the repo: the validator does not follow the symlinks in ~/.claude/skills
  for dir in "$REPO/claude/skills" "$CL/agents"; do
    claude plugin validate "$dir" >/dev/null 2>&1 || warn "claude plugin validate $dir reports problems; run it to see them"
  done
fi

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
printf '  %-12s %s\n' parts "$(tr '\n' ' ' < "$PARTS_FILE" 2>/dev/null)"
printf '  %-12s %s\n' agents "$(ls "$CL/agents" | sed 's/\.md$//' | tr '\n' ' ')"
[ -d "$STASH" ] && note "replaced files are in $STASH"
echo "done."
