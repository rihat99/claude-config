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
#   ~/.claude/settings.json                                -> copy of claude/settings.json (+ settings.macos.json on a Mac)
#   ~/.claude/skills/<name>, ~/.claude/agents/<name>.md    -> symlinks into this repo
#   ~/.local/bin/trash, ~/.trash/                          -> trash helper and folder
#   ~/.tmux.conf                                           -> symlink
#   tools (user-local): uv + ~/.claude/venv, jq, tectonic, resvg, node (Linux), LibreOffice AppImage (Linux), Claude Code
#   autoresearch skill from github.com/ramazan793/autoresearch_skill (vendor/, hooks merged into settings.json)
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CL="$HOME/.claude"
OS="$(uname -s)"; ARCH="$(uname -m)"
DO_TOOLS=1; DO_AUTORESEARCH=1
for a in "$@"; do
  case "$a" in
    --no-tools) DO_TOOLS=0 ;;
    --no-autoresearch) DO_AUTORESEARCH=0 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
  esac
done
export PATH="$HOME/.local/bin:$PATH"
log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*"; }

mkdir -p "$CL/skills" "$CL/agents" "$HOME/.local/bin" "$HOME/.trash"
STASH="$HOME/.trash/claude-config-install-$(date +%Y%m%d-%H%M%S)"

# Move an existing path out of the way (into ~/.trash) unless it is already our symlink.
stash() {
  local p="$1"
  [ -e "$p" ] || [ -L "$p" ] || return 0
  if [ -L "$p" ]; then
    case "$(readlink "$p")" in "$REPO"/*) rm -f "$p"; return 0 ;; esac
  fi
  mkdir -p "$STASH"
  mv "$p" "$STASH/$(basename "$p")"
  note "old $(basename "$p") moved to $STASH/"
}
link() { # link SRC DST
  local src="$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then return 0; fi
  stash "$dst"
  ln -s "$src" "$dst"
  note "linked $dst"
}

# ---------------------------------------------------------------- shell PATH
log "PATH"
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -f "$rc" ] || { [ "$(basename "$rc")" = ".zshrc" ] && [ "$OS" != "Darwin" ]; } && continue
  [ -f "$rc" ] || touch "$rc"
  grep -q 'HOME/.local/bin' "$rc" 2>/dev/null || { printf '\n# claude-config\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"; note "added ~/.local/bin to PATH in $rc"; }
done

# ---------------------------------------------------------------- config files
log "Config files"
link "$REPO/claude/CLAUDE.md"        "$CL/CLAUDE.md"
link "$REPO/claude/statusline.sh"    "$CL/statusline.sh"
link "$REPO/claude/keybindings.json" "$CL/keybindings.json"
link "$REPO/tmux/tmux.conf"          "$HOME/.tmux.conf"
link "$REPO/bin/trash"               "$HOME/.local/bin/trash"
chmod +x "$REPO/claude/statusline.sh" "$REPO/bin/trash"

# settings.json: template (+ macOS overlay), keeping any hooks block the autoresearch installer added.
python3 - "$REPO/claude/settings.json" "$CL/settings.json" "$OS" "$REPO/claude/settings.macos.json" <<'PY'
import json, os, sys
tpl, dst, osname, overlay = sys.argv[1:5]
new = json.load(open(tpl))
if osname == "Darwin" and os.path.isfile(overlay):
    new.update(json.load(open(overlay)))
old = {}
if os.path.isfile(dst):
    try:
        old = json.load(open(dst))
    except Exception:
        old = {}
if "hooks" in old and "hooks" not in new:
    new["hooks"] = old["hooks"]
if old != new:
    if old:
        os.makedirs(os.path.expanduser("~/.trash"), exist_ok=True)
        bak = os.path.expanduser("~/.trash/settings.json.before-install")
        json.dump(old, open(bak, "w"), indent=2)
    json.dump(new, open(dst, "w"), indent=2)
    open(dst, "a").write("\n")
    print("    wrote %s" % dst)
else:
    print("    settings.json unchanged")
PY
[ -f "$CL/settings.local.json" ] && { stash "$CL/settings.local.json"; note "settings.local.json retired (its rules live in settings.json now)"; }

# ---------------------------------------------------------------- skills and agents
log "Skills and agents"
RETIRED_SKILLS="codex-adversary diataxis-docs sphinx-docs write-tests design-principles file-naming python-standards subagent-orchestration"
for s in $RETIRED_SKILLS; do [ -e "$CL/skills/$s" ] && stash "$CL/skills/$s"; done
for d in "$REPO"/claude/skills/*/; do
  n="$(basename "$d")"
  link "${d%/}" "$CL/skills/$n"
done
for f in "$REPO"/claude/agents/*.md; do
  link "$f" "$CL/agents/$(basename "$f")"
done
# drop symlinks that point into this repo but whose target is gone
for p in "$CL"/skills/* "$CL"/agents/*; do
  [ -L "$p" ] || continue
  case "$(readlink "$p")" in "$REPO"/*) [ -e "$p" ] || { rm -f "$p"; note "removed stale link $p"; } ;; esac
done

# ---------------------------------------------------------------- tools
dl() { curl -fsSL --retry 3 -o "$2" "$1"; }
if [ "$DO_TOOLS" = 1 ]; then
  log "Tools (user-local, no sudo)"

  if ! command -v uv >/dev/null 2>&1; then
    note "installing uv"; curl -LsSf https://astral.sh/uv/install.sh | UV_NO_MODIFY_PATH=1 sh >/dev/null 2>&1 || warn "uv install failed"
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
    [ -n "$JQ" ] && { dl "https://github.com/jqlang/jq/releases/latest/download/$JQ" "$HOME/.local/bin/jq" && chmod +x "$HOME/.local/bin/jq" && note "installed jq" || warn "jq download failed"; }
  fi

  if ! command -v tectonic >/dev/null 2>&1; then
    note "installing tectonic (LaTeX)"
    (cd "$HOME/.local/bin" && curl --proto '=https' --tlsv1.2 -fsSL https://drop-sh.fullyjustified.net | sh >/dev/null 2>&1) && note "installed tectonic" || warn "tectonic install failed"
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
  fi
fi

# ---------------------------------------------------------------- autoresearch
if [ "$DO_AUTORESEARCH" = 1 ]; then
  log "Autoresearch skill"
  mkdir -p "$REPO/vendor"
  if [ -d "$REPO/vendor/autoresearch_skill/.git" ]; then
    git -C "$REPO/vendor/autoresearch_skill" pull -q --ff-only 2>/dev/null || warn "could not update autoresearch (offline?)"
  else
    git clone -q https://github.com/ramazan793/autoresearch_skill.git "$REPO/vendor/autoresearch_skill" 2>/dev/null || warn "could not clone autoresearch"
  fi
  if [ -f "$REPO/vendor/autoresearch_skill/install.sh" ]; then
    # their installer refuses a symlinked skill dir only if it is ours; it writes into ~/.claude/skills/autoresearch
    [ -L "$CL/skills/autoresearch" ] && rm -f "$CL/skills/autoresearch"
    bash "$REPO/vendor/autoresearch_skill/install.sh" >/dev/null 2>&1 && note "autoresearch installed (skill, hooks, mars_* agents)" || warn "autoresearch installer reported a problem"
    # user-invoked only: never auto-triggered by the model
    python3 - "$CL/skills/autoresearch/SKILL.md" <<'PY'
import sys
p = sys.argv[1]
try:
    lines = open(p).read().split("\n")
except FileNotFoundError:
    sys.exit(0)
if any(l.startswith("disable-model-invocation:") for l in lines[:40]):
    sys.exit(0)
# insert before the closing '---' of the frontmatter
idx = [i for i, l in enumerate(lines) if l.strip() == "---"]
if len(idx) >= 2:
    lines.insert(idx[1], "disable-model-invocation: true")
    open(p, "w").write("\n".join(lines))
    print("    autoresearch: marked user-invoked only")
PY
    # their installer backs settings.json up next to it; keep ~/.claude tidy
    for b in "$CL"/settings.json.bak.*; do [ -e "$b" ] && mv "$b" "$HOME/.trash/" 2>/dev/null; done
    [ -f "$HOME/.config/autoresearch/telegram.env" ] && grep -q 'TG_BOT_TOKEN=$\|TG_BOT_TOKEN=""\|<' "$HOME/.config/autoresearch/telegram.env" 2>/dev/null && note "Telegram not configured: edit ~/.config/autoresearch/telegram.env"
  fi
fi

# ---------------------------------------------------------------- git identity
if [ -z "$(git config --global user.email 2>/dev/null)" ]; then
  git config --global user.name "rihat99"; git config --global user.email "mr.rihat@gmail.com"
  note "set git identity (rihat99 <mr.rihat@gmail.com>)"
fi

# ---------------------------------------------------------------- summary
log "Summary on $(hostname) ($OS $ARCH)"
have() { if command -v "$1" >/dev/null 2>&1; then printf '  %-12s %s\n' "$1" "$(command -v "$1")"; else printf '  %-12s MISSING\n' "$1"; fi; }
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
