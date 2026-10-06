#!/usr/bin/env bash
# Move leftover Claude Code state on this machine into the trash. Dry run by default.
#
#   bash cleanup.sh          # show what would move
#   bash cleanup.sh --yes    # move it
#
# Moved (via bin/trash, so nothing is deleted or overwritten) to
# <home trash>/claude-cleanup-<date>/ :
#   ~/.claude/handoffs, ~/.claude/downloads/*, ~/.claude/*.bak*, *.pre-migrate, any *.codex.* file
# Not touched: chats (Claude Code removes transcripts older than 30 days by itself and keeps
# Desktop sessions), jobs/ daemon/ tasks/ (live background-session state), memory/ folders.
set -uo pipefail
CL="$HOME/.claude"; YES=0
for a in "$@"; do case "$a" in --yes|-y) YES=1 ;; *) echo "unknown arg $a" >&2; exit 2 ;; esac; done
[ -d "$CL" ] || { echo "no $CL on this machine"; exit 0; }
TRASH_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bin/trash"
TRASH="${TRASH_DIR:-$HOME/.trash}/claude-cleanup-$(date +%Y%m%d)"   # on macOS ~/.trash is the Finder Trash

items=()
[ -e "$CL/handoffs" ] && items+=("$CL/handoffs")
for p in "$CL"/downloads/* "$CL"/*.bak* "$CL"/*.pre-migrate; do [ -e "$p" ] && items+=("$p"); done
while IFS= read -r -d '' p; do items+=("$p"); done \
  < <(find "$CL" -maxdepth 3 -name '*.codex.*' -not -path "*/handoffs/*" -print0 2>/dev/null)

if [ ${#items[@]} -eq 0 ]; then
  echo "nothing to clean; ~/.claude is $(du -sh "$CL" 2>/dev/null | cut -f1)"
  exit 0
fi
echo "== to $TRASH"
printf '%s\0' "${items[@]}" | sort -zu | while IFS= read -r -d '' p; do
  printf '   %-8s %s\n' "$(du -sh "$p" 2>/dev/null | cut -f1)" "${p#$HOME/}"
  [ "$YES" = 1 ] && TRASH_DIR="$TRASH" "$TRASH_BIN" "$p" >/dev/null
done
echo "== ~/.claude now: $(du -sh "$CL" 2>/dev/null | cut -f1)"
[ "$YES" = 1 ] || echo "(dry run; add --yes to apply)"
