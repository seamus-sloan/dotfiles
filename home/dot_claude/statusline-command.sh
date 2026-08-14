#!/usr/bin/env zsh

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Unknown Model"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
plan_tokens=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')

# Shorten the working directory: replace $HOME with ~
short_cwd="${cwd/#$HOME/~}"

# Build a progress bar of given percentage and width
make_bar() {
  local pct=$1
  local width=${2:-10}
  local filled=0
  if [ -n "$pct" ] && [ "$pct" -eq "$pct" ] 2>/dev/null; then
    filled=$(( pct * width / 100 ))
    [ $filled -gt $width ] && filled=$width
  fi
  local empty=$(( width - filled ))
  local bar=""
  local i
  for (( i=0; i<filled; i++ )); do bar="${bar}█"; done
  for (( i=0; i<empty; i++ )); do bar="${bar}░"; done
  echo "$bar"
}

# Context usage bar
if [ -n "$used_pct" ]; then
  ctx_bar=$(make_bar "$used_pct" 10)
  ctx_label="ctx ${ctx_bar} ${used_pct}%"
else
  ctx_label="ctx --"
fi

# Plan mode usage bar: use cache_creation tokens as a proxy for plan/thinking token usage
# expressed as a percentage of the context window
if [ "$context_size" -gt 0 ] 2>/dev/null && [ "$plan_tokens" -gt 0 ] 2>/dev/null; then
  plan_pct=$(( plan_tokens * 100 / context_size ))
  [ $plan_pct -gt 100 ] && plan_pct=100
  plan_bar=$(make_bar "$plan_pct" 10)
  plan_label="plan ${plan_bar} ${plan_pct}%"
elif [ "$cache_read" -gt 0 ] 2>/dev/null; then
  plan_pct=$(( cache_read * 100 / context_size ))
  [ $plan_pct -gt 100 ] && plan_pct=100
  plan_bar=$(make_bar "$plan_pct" 10)
  plan_label="plan ${plan_bar} ${plan_pct}%"
else
  plan_label="plan --"
fi

printf "%s  %s  %s  %s" "$model" "$short_cwd" "$ctx_label" "$plan_label"
