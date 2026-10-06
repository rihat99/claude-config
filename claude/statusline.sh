#!/bin/bash
# Claude Code status line: [Model · effort] ctx 42% 105k/1.00M │ 5h 20% 6h0m left │ 7d 55% 2d13h left
# Input: JSON on stdin (see https://code.claude.com/docs/en/statusline). Needs jq.
export LC_ALL=C   # decimal point, not comma, whatever the machine's locale
command -v jq >/dev/null 2>&1 || { printf '[status line needs jq]\n'; exit 0; }
input=$(cat)

C_RESET=$'\033[0m'
C_DIM=$'\033[2m'
C_BOLD=$'\033[1m'
C_CYAN=$'\033[36m'
C_MAGENTA=$'\033[35m'
C_GREEN=$'\033[32m'
C_YELLOW=$'\033[33m'
C_RED=$'\033[31m'
C_GRAY=$'\033[90m'
C_BLUE=$'\033[34m'

pct_color() {
  local pct="$1"
  if [ "$pct" -ge 80 ]; then
    printf '%s' "$C_RED"
  elif [ "$pct" -ge 50 ]; then
    printf '%s' "$C_YELLOW"
  else
    printf '%s' "$C_GREEN"
  fi
}

fmt_tokens() {
  local n="$1"
  [ -z "$n" ] && { printf ''; return; }
  if [ "$n" -ge 1000000 ]; then
    awk "BEGIN{printf \"%.2fM\", $n/1000000}"
  elif [ "$n" -ge 1000 ]; then
    awk "BEGIN{printf \"%.1fk\", $n/1000}"
  else
    printf '%s' "$n"
  fi
}

time_left() {
  local raw="$1"
  [ -z "$raw" ] && return
  local target_ts
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    target_ts="$raw"
  else
    target_ts=$(date -d "$raw" +%s 2>/dev/null)
  fi
  [ -z "$target_ts" ] && return
  local now=$(date +%s)
  local diff=$((target_ts - now))
  if [ "$diff" -le 0 ]; then
    echo "0m"
    return
  fi
  local days=$((diff / 86400))
  local hours=$(((diff % 86400) / 3600))
  local mins=$(((diff % 3600) / 60))
  if [ "$days" -gt 0 ]; then
    echo "${days}d${hours}h"
  elif [ "$hours" -gt 0 ]; then
    echo "${hours}h${mins}m"
  else
    echo "${mins}m"
  fi
}

MODEL=$(echo "$input" | jq -r '.model.display_name // "claude"')
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')
FAST=$(echo "$input" | jq -r '.fast_mode // false')
CTX_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CTX_IN=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
CTX_OUT=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
CTX_USED=$((CTX_IN + CTX_OUT))
CTX_TOTAL=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

FIVE_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
WEEK_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
FIVE_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
WEEK_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Model and effort, e.g. [Opus · xhigh]. Effort is colored by level.
case "$EFFORT" in
  max)   EFF_COLOR="$C_RED" ;;
  xhigh) EFF_COLOR="$C_MAGENTA" ;;
  high)  EFF_COLOR="$C_BLUE" ;;
  medium) EFF_COLOR="$C_GREEN" ;;
  low)   EFF_COLOR="$C_GRAY" ;;
  *)     EFF_COLOR="$C_GRAY" ;;
esac
if [ -n "$EFFORT" ]; then
  OUT="${C_BOLD}${C_CYAN}[${MODEL}${C_RESET}${C_GRAY} · ${C_RESET}${EFF_COLOR}${EFFORT}${C_RESET}${C_BOLD}${C_CYAN}]${C_RESET}"
else
  OUT="${C_BOLD}${C_CYAN}[${MODEL}]${C_RESET}"
fi
[ "$FAST" = "true" ] && OUT="${OUT} ${C_YELLOW}fast${C_RESET}"

CTX_COLOR=$(pct_color "$CTX_PCT")
CTX_TOKENS=""
if [ "$CTX_USED" -gt 0 ]; then
  USED_H=$(fmt_tokens "$CTX_USED")
  if [ -n "$CTX_TOTAL" ]; then
    TOTAL_H=$(fmt_tokens "$CTX_TOTAL")
    CTX_TOKENS=" ${C_MAGENTA}${USED_H}${C_RESET}${C_GRAY}/${TOTAL_H}${C_RESET}"
  else
    CTX_TOKENS=" ${C_MAGENTA}${USED_H}${C_RESET}"
  fi
fi
OUT="${OUT} ${C_DIM}ctx${C_RESET} ${CTX_COLOR}${CTX_PCT}%${C_RESET}${CTX_TOKENS}"

SEP="${C_GRAY} │ ${C_RESET}"

if [ -n "$FIVE_PCT" ]; then
  FH=$(printf '%.0f' "$FIVE_PCT")
  FH_COLOR=$(pct_color "$FH")
  LEFT=$(time_left "$FIVE_RESET")
  if [ -n "$LEFT" ]; then
    OUT="${OUT}${SEP}${C_DIM}5h${C_RESET} ${FH_COLOR}${FH}%${C_RESET} ${C_GRAY}${LEFT} left${C_RESET}"
  else
    OUT="${OUT}${SEP}${C_DIM}5h${C_RESET} ${FH_COLOR}${FH}%${C_RESET}"
  fi
fi

if [ -n "$WEEK_PCT" ]; then
  WK=$(printf '%.0f' "$WEEK_PCT")
  WK_COLOR=$(pct_color "$WK")
  LEFT=$(time_left "$WEEK_RESET")
  if [ -n "$LEFT" ]; then
    OUT="${OUT}${SEP}${C_DIM}7d${C_RESET} ${WK_COLOR}${WK}%${C_RESET} ${C_GRAY}${LEFT} left${C_RESET}"
  else
    OUT="${OUT}${SEP}${C_DIM}7d${C_RESET} ${WK_COLOR}${WK}%${C_RESET}"
  fi
fi

if [ -z "$FIVE_PCT" ] && [ -z "$WEEK_PCT" ]; then
  OUT="${OUT}${SEP}${C_DIM}limits: waiting for first call${C_RESET}"
fi

printf '%s\n' "$OUT"
