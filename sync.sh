#!/usr/bin/env bash
# Push this repo to the other machines over SSH and run install.sh there.
# Run from the machine that has the latest version (normally the Mac).
#
#   bash sync.sh                 # all hosts
#   bash sync.sh robotics2       # one or more hosts
#   bash sync.sh --no-tools ...  # pass install.sh flags after the hosts
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALL_HOSTS=(rikhat_ws robotics1 robotics2 robotics3 robomed4)
HOSTS=(); FLAGS=()
for a in "$@"; do case "$a" in --*) FLAGS+=("$a") ;; *) HOSTS+=("$a") ;; esac; done
[ ${#HOSTS[@]} -gt 0 ] || HOSTS=("${ALL_HOSTS[@]}")

for h in "${HOSTS[@]}"; do
  printf '\n\033[1;32m#### %s ####\033[0m\n' "$h"
  if ! ssh -o BatchMode=yes -o ConnectTimeout=8 "$h" true 2>/dev/null; then
    echo "unreachable, skipped"; continue
  fi
  rsync -a --delete --exclude vendor/ --exclude .DS_Store "$REPO/" "$h:claude-config/" || { echo "rsync failed"; continue; }
  ssh -o BatchMode=yes "$h" "bash ~/claude-config/install.sh ${FLAGS[*]:-}"
done
