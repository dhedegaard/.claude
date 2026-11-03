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

# PR for the current branch: prefer the PR Claude Code already reports, else a
# cached `gh` lookup (refreshed in the background, so this never blocks)
if [ -n "$cwd" ]; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null)
  if [ -n "$branch" ] && [ "$branch" != main ] && [ "$branch" != master ]; then
    pr_num=$(echo "$input" | jq -r '.pr.number // empty')
    if [ -n "$pr_num" ]; then
      pr_state=$(echo "$input" | jq -r '.pr.review_state // "open"')
      pr_url=$(echo "$input" | jq -r '.pr.url // empty')
      pr_prefix="#"
      [ "$(echo "$input" | jq -r '.pr.kind // empty')" = "mr" ] && pr_prefix="!"
    else
      pr_prefix="#"
      top=$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)
      if [ -n "$top" ]; then
        cache_dir="$HOME/.claude/statusline-cache"
        mkdir -p "$cache_dir" 2>/dev/null
        key=$(printf '%s\n%s' "$top" "$branch" | shasum | cut -c1-16)
        cache="$cache_dir/pr-$key"
        mtime=$(stat -f %m "$cache" 2>/dev/null || echo 0)
        if [ $(( $(date +%s) - mtime )) -ge 60 ]; then
          touch "$cache"  # claims the refresh so concurrent runs don't pile up
          (
            cd "$top" || exit 0
            out=$(env -u GH_TOKEN -u GITHUB_TOKEN gh pr view "$branch" --json number,state,isDraft,url \
              --jq '"\(.number) \(if .isDraft then "draft" else (.state | ascii_downcase) end) \(.url)"' 2>/dev/null) || out=""
            printf '%s' "$out" > "$cache.tmp.$$" && mv "$cache.tmp.$$" "$cache"
          ) </dev/null >/dev/null 2>&1 &
          disown 2>/dev/null
        fi
        read -r pr_num pr_state pr_url < "$cache" 2>/dev/null
      fi
    fi
    if [ -n "$pr_num" ]; then
      case "$pr_state" in
        open|approved) pc='\033[32m' ;;
        merged) pc="$MAGENTA" ;;
        closed|changes_requested) pc='\033[31m' ;;
        *) pc="$DIM" ;;
      esac
      pr_label="${pr_prefix}${pr_num}"
      if [ -n "$pr_url" ]; then
        # OSC 8 hyperlink; the doubled backslash survives the final printf %b as one
        pr_label=$(printf '\033]8;;%s\033\\\\%s\033]8;;\033\\\\' "$pr_url" "$pr_label")
      fi
      pr_part="$(printf "${DIM}${MAGENTA}PR${RESET} ${pc}%s${RESET} ${DIM}%s${RESET}" "$pr_label" "$pr_state")"
    fi
  fi
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

# PR goes last
[ -n "$pr_part" ] && parts+=("$pr_part")

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
