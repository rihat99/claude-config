#!/usr/bin/env bash
# Push this repo to the other machines over SSH and run install.sh there.
# Run from the machine that has the latest version (normally the Mac).
#
#   bash sync.sh                 # all hosts
#   bash sync.sh robotics2       # one or more hosts
#   bash sync.sh --no-tools ...  # pass install.sh --no-tools
#   bash sync.sh --shell --tmux robotics2   # switch an optional part on there (also --no-shell, --no-tmux)
#   bash sync.sh --force ...     # overwrite a remote copy that has its own edits or commits
#
# A host whose ~/dotfiles has uncommitted edits, or commits this copy does not have, is
# skipped so nothing is lost: copy those changes back here first, or pass --force.
# The remote trash/ folder (bin/trash inside the repo) is never touched.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALL_HOSTS=(rikhat_ws robotics1 robotics2 robotics3 robomed4)
HOSTS=(); FLAGS=(); FORCE=0
for a in "$@"; do
  case "$a" in
    --force) FORCE=1 ;;
    --no-tools|--shell|--no-shell|--tmux|--no-tmux|--tmux-theme=*) FLAGS+=("$a") ;;
    -*) echo "unknown flag $a" >&2; exit 2 ;;
    *) HOSTS+=("$a") ;;
  esac
done
[ ${#HOSTS[@]} -gt 0 ] || HOSTS=("${ALL_HOSTS[@]}")

for h in "${HOSTS[@]}"; do
  printf '\n\033[1;32m#### %s ####\033[0m\n' "$h"
  if ! ssh -o BatchMode=yes -o ConnectTimeout=8 "$h" true 2>/dev/null; then
    echo "unreachable, skipped"; continue
  fi
  if [ "$FORCE" = 0 ]; then
    # first line: remote HEAD (or NONE), then any uncommitted changes
    state="$(ssh -o BatchMode=yes "$h" 'cd ~/dotfiles 2>/dev/null || { echo NONE; exit 0; }; git rev-parse HEAD 2>/dev/null || echo NONE; git status --porcelain 2>/dev/null | head -20')"
    rhead="$(printf '%s\n' "$state" | head -1)"
    dirty="$(printf '%s\n' "$state" | sed -n '2,$p')"
    if [ -n "$dirty" ]; then
      echo "skipped: ~/dotfiles on $h has uncommitted changes (copy them back here, or --force):"; echo "$dirty"; continue
    fi
    if [ "$rhead" != NONE ] && ! git -C "$REPO" merge-base --is-ancestor "$rhead" HEAD 2>/dev/null; then
      echo "skipped: $h has commits this copy does not have ($rhead); copy them back here, or --force"; continue
    fi
  fi
  rsync -a --delete --exclude .DS_Store --exclude /trash/ "$REPO/" "$h:dotfiles/" || { echo "rsync failed"; continue; }
  ssh -o BatchMode=yes "$h" "bash ~/dotfiles/install.sh ${FLAGS[*]:-}"
done
