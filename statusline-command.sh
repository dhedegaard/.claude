#!/usr/bin/env bash
input=$(cat)

# ANSI color helpers
color_for_pct() {
  local pct="$1"
  local rounded
  rounded=$(printf '%.0f' "$pct")
  if [ "$rounded" -ge 80 ]; then
    printf '\033[31m'   # red
  elif [ "$rounded" -ge 50 ]; then
    printf '\033[33m'   # yellow
  else
    printf '\033[32m'   # green
  fi
}

# Format a unix epoch as "HH:MM" in local time
format_reset_time() {
  local epoch="$1"
  date -r "$epoch" '+%H:%M' 2>/dev/null
}

RESET='\033[0m'
DIM='\033[2m'
CYAN='\033[36m'
BLUE='\033[34m'
MAGENTA='\033[35m'

# Context window usage
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

# Rate limits
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Model, effort, and path
model=$(echo "$input" | jq -r '.model.display_name // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

parts=()

# Model name (with effort level if present)
if [ -n "$model" ]; then
  if [ -n "$effort" ]; then
    parts+=("$(printf "${CYAN}%s${RESET} ${DIM}[%s]${RESET}" "$model" "$effort")")
  else
    parts+=("$(printf "${CYAN}%s${RESET}" "$model")")
  fi
fi

# Current working directory (replace $HOME prefix with ~)
if [ -n "$cwd" ]; then
  display_cwd="${cwd/#$HOME/\~}"
  parts+=("$(printf "${BLUE}%s${RESET}" "$display_cwd")")
fi

if [ -n "$used" ] && [ -n "$total_input" ] && [ -n "$ctx_size" ]; then
  col=$(color_for_pct "$used")
  parts+=("$(printf "${DIM}${MAGENTA}ctx:${RESET} ${col}%.0f%%${RESET} ${DIM}(%s/%sk)${RESET}" "$used" "$(( total_input / 1000 ))" "$(( ctx_size / 1000 ))")")
elif [ -n "$used" ]; then
  col=$(color_for_pct "$used")
  parts+=("$(printf "${DIM}${MAGENTA}ctx:${RESET} ${col}%.0f%%${RESET} ${DIM}used${RESET}" "$used")")
fi

if [ -n "$five_pct" ]; then
  col=$(color_for_pct "$five_pct")
  reset_str=""
  if [ -n "$five_reset" ]; then
    rt=$(format_reset_time "$five_reset")
    reset_str="$(printf " ${DIM}@${RESET}${rt}")"
  fi
  parts+=("$(printf "${DIM}${MAGENTA}5h:${RESET} ${col}%.0f%%${RESET}${reset_str}" "$five_pct")")
fi

if [ -n "$week_pct" ]; then
  col=$(color_for_pct "$week_pct")
  reset_str=""
  if [ -n "$week_reset" ]; then
    rt=$(date -r "$week_reset" '+%a %H:%M' 2>/dev/null)
    reset_str="$(printf " ${DIM}@${RESET}${rt}")"
  fi
  parts+=("$(printf "${DIM}${MAGENTA}7d:${RESET} ${col}%.0f%%${RESET}${reset_str}" "$week_pct")")
fi

if [ ${#parts[@]} -gt 0 ]; then
  sep="$(printf " ${DIM}|${RESET} ")"
  result=""
  for part in "${parts[@]}"; do
    if [ -z "$result" ]; then
      result="$part"
    else
      result="${result}${sep}${part}"
    fi
  done
  printf '%b\n' "$result"
fi
