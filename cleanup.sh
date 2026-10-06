#!/usr/bin/env bash
# Clean old Claude Code state on this machine. Dry run by default.
#
#   bash cleanup.sh              # show what would happen
#   bash cleanup.sh --yes        # do it
#   bash cleanup.sh --days 60    # change the age threshold (default 30)
#
# Deleted outright (caches and chat transcripts older than N days):
#   ~/.claude/projects/*/<session>.jsonl and the session's folder
#   ~/.claude/{file-history,session-env,shell-snapshots,debug,backups,paste-cache,telemetry,todos}/*
# Moved to ~/.trash/claude-cleanup-<date>/ (regardless of age):
#   ~/.claude/{handoffs,jobs,tasks,daemon,daemon.log,downloads/*}
#   ~/.claude/*.bak* , *.pre-migrate, CLAUDE.md.bak*, any *.codex.* file
set -uo pipefail
CL="$HOME/.claude"; DAYS=30; YES=0
while [ $# -gt 0 ]; do
  case "$1" in --yes|-y) YES=1 ;; --days) DAYS="$2"; shift ;; *) echo "unknown arg $1" >&2; exit 2 ;; esac; shift
done
TRASH="$HOME/.trash/claude-cleanup-$(date +%Y%m%d)"
[ -d "$CL" ] || { echo "no $CL on this machine"; exit 0; }
bytes() { [ $# -gt 0 ] || { echo "0 MB"; return; }; du -sk "$@" 2>/dev/null | awk '{s+=$1} END {printf "%.0f MB", s/1024}'; }
run() { if [ "$YES" = 1 ]; then "$@"; fi; }

echo "== chats older than $DAYS days (deleted)"
OLD_JSONL=$(find "$CL/projects" -mindepth 2 -maxdepth 2 -name '*.jsonl' -mtime +"$DAYS" 2>/dev/null)
n=0; dirs=""
for f in $OLD_JSONL; do
  n=$((n+1)); sid="$(basename "${f%.jsonl}")"; sid="${sid#agent-}"
  d="$(dirname "$f")/$sid"; [ -d "$d" ] && dirs="$dirs $d"
done
echo "   $n transcript files, $(bytes $OLD_JSONL $dirs)"
if [ "$YES" = 1 ]; then
  for f in $OLD_JSONL; do rm -f "$f"; done
  for d in $dirs; do rm -rf "$d"; done
  # remove session folders whose transcript is gone, then empty project dirs (memory/ folders are kept)
  for d in "$CL"/projects/*/*/; do
    [ -d "$d" ] || continue; b="$(basename "$d")"; p="$(dirname "$d")"
    case "$b" in memory|transcripts) continue ;; esac
    [ -f "$p/$b.jsonl" ] || [ -f "$p/agent-$b.jsonl" ] || { [ "$(find "$d" -type f -newermt "-$DAYS days" 2>/dev/null | head -1)" ] || rm -rf "$d"; }
  done
  find "$CL/projects" -mindepth 1 -type d -empty -delete 2>/dev/null
fi

echo "== caches older than $DAYS days (deleted)"
for sub in file-history session-env shell-snapshots debug backups paste-cache telemetry todos; do
  [ -d "$CL/$sub" ] || continue
  items=$(find "$CL/$sub" -mindepth 1 -maxdepth 1 -mtime +"$DAYS" 2>/dev/null)
  [ -n "$items" ] || continue
  echo "   $sub: $(echo "$items" | wc -l | tr -d ' ') items, $(bytes $items)"
  if [ "$YES" = 1 ]; then echo "$items" | while read -r p; do rm -rf "$p"; done; fi
done

echo "== moved to $TRASH"
tomove=""
for p in handoffs jobs tasks daemon daemon.log; do [ -e "$CL/$p" ] && tomove="$tomove $CL/$p"; done
for p in "$CL"/downloads/* "$CL"/*.bak* "$CL"/*.pre-migrate "$CL"/CLAUDE.md.bak* "$CL"/settings.json.bak*; do [ -e "$p" ] && tomove="$tomove $p"; done
codex=$(find "$CL" -maxdepth 3 -name '*.codex.*' -not -path "*/handoffs/*" 2>/dev/null); tomove="$tomove $codex"
if [ -n "$(echo $tomove)" ]; then
  for p in $tomove; do echo "   $(basename "$p")  $(bytes "$p")"; done
  if [ "$YES" = 1 ]; then
    mkdir -p "$TRASH"
    for p in $tomove; do
      dst="$TRASH/$(basename "$p")"; [ -e "$dst" ] && dst="$dst.$(date +%H%M%S)"
      mv "$p" "$dst"
    done
  fi
else
  echo "   nothing"
fi

echo "== ~/.claude size now: $(bytes "$CL")"
[ "$YES" = 1 ] || echo "(dry run; add --yes to apply)"
