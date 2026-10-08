#!/usr/bin/env zsh
# Claude Code statusline: a labeled grid stretched across the terminal.
#
#   model    …   effort   …   style    …   mode     …
#   dir      …   branch   …   pr       …   agents   …
#   context  …   tokens   …   cost     …   lines    …
#   session  …                5h limit …   7d limit …
#
# Four columns on wide terminals, two or one on narrow ones. A value with
# nothing to show prints as a dim dash, so cells never move. PR icons need a
# Nerd Font.

setopt extended_glob
zmodload zsh/datetime
[[ ${LC_ALL:-${LC_CTYPE:-$LANG}} == *UTF-8* ]] || export LC_ALL=en_US.UTF-8

input=$(cat)

eval "$(jq -r '
  def pct: if . == null then "" else round end;
  @sh "
  model=\(.model.display_name // "?")
  fast=\(.fast_mode // false)
  effort=\(.effort.level // "")
  style=\(.output_style.name // "default")
  cwd=\(.workspace.current_dir // .cwd // "")
  transcript=\(.transcript_path // "")
  session_id=\(.session_id // "")
  title=\(.session_name // "")
  ctx_pct=\(.context_window.used_percentage | pct)
  ctx_used=\(.context_window.total_input_tokens // 0)
  ctx_size=\(.context_window.context_window_size // 0)
  cost=\(.cost.total_cost_usd // 0)
  added=\(.cost.total_lines_added // 0)
  removed=\(.cost.total_lines_removed // 0)
  rl_5h=\(.rate_limits.five_hour.used_percentage | pct)
  rl_5h_at=\(.rate_limits.five_hour.resets_at // "")
  rl_7d=\(.rate_limits.seven_day.used_percentage | pct)
  rl_7d_at=\(.rate_limits.seven_day.resets_at // "")
  pr_num=\(.pr.number // "")
  pr_url=\(.pr.url // "")
  pr_review=\(.pr.review_state // "")
  "' <<<"$input")"

state_dir=${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/claude-statusline
mkdir -p "$state_dir"

reset=$'\e[0m' dim=$'\e[2m' bold=$'\e[1m'
red=$'\e[31m' green=$'\e[32m' yellow=$'\e[33m' blue=$'\e[34m' magenta=$'\e[35m' cyan=$'\e[36m'
none="${dim}—${reset}"

# ── Layout ───────────────────────────────────────────────────────────────────
# Claude Code sets COLUMNS; keep a small right margin so rows never wrap. In
# the four-column grid the last column is a fixed 32 wide (enough for
# "7d limit 100% · resets in 6d 23h") and the others share the rest, so the
# grid reaches the right edge and columns stay put as values change.
usable=$(( ${COLUMNS:-120} - 4 ))
lw=9                       # label width
if (( usable >= 140 )); then
  ncols=4 cw=$(( (usable - 32) / 3 ))
elif (( usable >= 68 )); then
  ncols=2 cw=$(( usable / 2 ))
else
  ncols=1 cw=$usable
fi
vw=$(( cw - lw - 2 ))      # widest value that still leaves a gap

# ── Helpers ──────────────────────────────────────────────────────────────────
# 1234 → 1k, 1234567 → 1.2M
human() {
  local n=${1:-0} s
  if (( n >= 1000000 )); then
    s=$(printf '%.1f' $(( n / 1000000.0 ))); print -n "${s%.0}M"
  elif (( n >= 1000 )); then
    print -n "$(( n / 1000 ))k"
  else
    print -n "$n"
  fi
}

# Green under 50%, yellow under 80%, red above.
level() {
  if (( $1 >= 80 )); then print -n $red
  elif (( $1 >= 50 )); then print -n $yellow
  else print -n $green; fi
}

bar() {
  local pct=$1 width=10 filled i out=""
  filled=$(( pct * width / 100 ))
  (( filled > width )) && filled=$width
  for (( i = 0; i < width; i++ )); do
    (( i < filled )) && out+="█" || out+="░"
  done
  print -n "$out"
}

# time_left <epoch>: time left, as 3d 4h, 1h 20m or 45m.
time_left() {
  local s=$(( $1 - EPOCHSECONDS ))
  (( s < 0 )) && s=0
  local d=$(( s / 86400 )) h=$(( s % 86400 / 3600 )) m=$(( s % 3600 / 60 ))
  if (( d > 0 )); then print -n "${d}d ${h}h"
  elif (( h > 0 )); then print -n "${h}h ${m}m"
  else print -n "${m}m"; fi
}

# clip <max> <text>: cut the end off, marking it with …
clip() {
  local s=$2
  (( ${#s} > $1 )) && s="${s[1,$1-1]}…"
  print -rn -- "$s"
}

# clip_left <max> <text>: cut the start off instead, for paths.
clip_left() {
  local s=$2
  (( ${#s} > $1 )) && s="…${s[-($1-1),-1]}"
  print -rn -- "$s"
}

# vis <text>: width on screen, not counting color codes or OSC 8 links.
vis() {
  local s=${1//$'\e]8;;'[^$'\e']#$'\e\\'/}
  s=${s//$'\e['[0-9;]#m/}
  print -n ${#s}
}

# cell <label> <value> <width>: dim label, value, then spaces out to width.
# A width of 0 skips the padding (last cell in a row).
cell() {
  local out="${dim}${(r:lw:)1}${reset}${2:-$none}" pad
  if (( $3 > 0 )); then
    pad=$(( $3 - $(vis "$out") ))
    (( pad < 1 )) && pad=1
    out+=$(printf '%*s' $pad '')
  fi
  print -rn -- "$out"
}

# ── Row 1: model │ effort │ style │ mode ─────────────────────────────────────
model_v="${bold}$(clip $vw "$model")${reset}"
[[ $fast == true ]] && model_v+=" ${yellow}fast${reset}"

effort_v=""
[[ -n $effort ]] && effort_v="${magenta}${effort}${reset}"

# "precise:precise" is a plugin style named after its plugin; show it once.
[[ $style == *:* && ${style%%:*} == ${style#*:} ]] && style=${style#*:}
style_v="${cyan}$(clip $vw "$style")${reset}"

# The JSON has no permission mode; the transcript records it on each prompt,
# so a mid-turn shift+tab shows up after the next prompt.
mode=""
[[ -r $transcript ]] && mode=$(tac "$transcript" | grep -m1 -o '"permissionMode":"[^"]*"' | cut -d'"' -f4)
case $mode in
  default)           mode_v="manual" ;;
  auto)              mode_v="${green}auto${reset}" ;;
  acceptEdits)       mode_v="${magenta}accept edits${reset}" ;;
  plan)              mode_v="${cyan}plan${reset}" ;;
  bypassPermissions) mode_v="${red}bypass${reset}" ;;
  dontAsk)           mode_v="${red}don't ask${reset}" ;;
  *)                 mode_v="" ;;
esac

# ── Row 2: dir │ branch │ pr │ agents ────────────────────────────────────────
dir_v=""
[[ -n $cwd ]] && dir_v="${blue}$(clip_left $vw "${cwd/#$HOME/~}")${reset}"

branch="" branch_v=""
if [[ -n $cwd ]] && gs=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" status --porcelain=v2 --branch 2>/dev/null); then
  dirty="" ahead=0 behind=0 extra=""
  for line in "${(@f)gs}"; do
    case $line in
      '# branch.head '*) branch=${line#'# branch.head '} ;;
      '# branch.ab '*)   ab=(${=line}); ahead=${ab[3]#+}; behind=${ab[4]#-} ;;
      '#'*) ;;
      *) dirty="*" ;;
    esac
  done
  (( ahead > 0 )) && extra+=" ↑${ahead}"
  (( behind > 0 )) && extra+=" ↓${behind}"
  [[ $cwd == $HOME/worktrees/* ]] && extra+=" wt"
  branch_v="${green}$(clip $(( vw - ${#dirty} - ${#extra} )) "$branch")${reset}"
  branch_v+="${yellow}${dirty}${reset}${dim}${extra}${reset}"
fi

# Claude Code's pr object only covers open PRs: it drops merged and closed
# ones and never reports conflicts. So ask gh, at most once a minute per
# directory and branch, in the background; this run uses the last answer.
gh_num="" gh_url="" gh_state="" gh_draft="" gh_mergeable="" gh_review=""
if [[ -n $branch && $branch != '(detached)' ]] && (( $+commands[gh] )); then
  cache=$state_dir/pr-${${:-$cwd@$branch}//[^A-Za-z0-9._-]/_}.json
  fresh=( $cache.at(N.ms-60) )
  if (( ! $#fresh )); then
    : >| $cache.at
    ( cd "$cwd" && { gh pr view --json number,url,state,isDraft,mergeable,reviewDecision 2>/dev/null || print '{}' } >| $cache.tmp \
      && mv -f $cache.tmp $cache ) &>/dev/null &!
  fi
  [[ -s $cache ]] && eval "$(jq -r '@sh "
    gh_num=\(.number // "") gh_url=\(.url // "") gh_state=\(.state // "")
    gh_draft=\(.isDraft // false) gh_mergeable=\(.mergeable // "") gh_review=\(.reviewDecision // "")
    "' $cache 2>/dev/null)"
fi

pr_status="" review=""
if [[ -n $gh_num ]]; then
  pr_num=$gh_num pr_url=$gh_url review=$gh_review
  case $gh_state in
    MERGED) pr_status=merged ;;
    CLOSED) pr_status=closed ;;
    *) if [[ $gh_mergeable == CONFLICTING ]]; then pr_status=conflict
       elif [[ $gh_draft == true ]]; then pr_status=draft
       else pr_status=open; fi ;;
  esac
elif [[ -n $pr_num ]]; then
  case $pr_review in
    draft)             pr_status=draft ;;
    approved)          pr_status=open review=APPROVED ;;
    changes_requested) pr_status=open review=CHANGES_REQUESTED ;;
    *)                 pr_status=open review=REVIEW_REQUIRED ;;
  esac
fi

# GitHub's colors and octicons (Nerd Font) for each state.
pr_v=""
if [[ -n $pr_status ]]; then
  case $pr_status in
    open)     pr_color=$'\e[38;2;63;185;80m'   pr_icon=$'' ;;
    draft)    pr_color=$'\e[38;2;139;148;158m' pr_icon=$'' ;;
    merged)   pr_color=$'\e[38;2;163;113;247m' pr_icon=$'' ;;
    conflict) pr_color=$'\e[38;2;219;109;40m'  pr_icon=$'' ;;
    closed)   pr_color=$'\e[38;2;248;81;73m'   pr_icon=$'' ;;
  esac
  pr_text="${pr_icon} #${pr_num} ${pr_status}"
  pr_v=$'\e]8;;'"${pr_url}"$'\e\\'"${pr_color}${pr_text}${reset}"$'\e]8;;\e\\'

  # Review decision, while the PR is still open, if it fits.
  case $review in
    APPROVED)          review_v="${green}approved${reset}" review_text=approved ;;
    CHANGES_REQUESTED) review_v="${red}changes req.${reset}" review_text="changes req." ;;
    REVIEW_REQUIRED)   review_v="${yellow}needs review${reset}" review_text="needs review" ;;
    *)                 review_v="" review_text="" ;;
  esac
  if [[ -n $review_v && $pr_status != (merged|closed) ]] \
     && (( ${#pr_text} + 3 + ${#review_text} <= vw )); then
    pr_v+=" ${dim}·${reset} ${review_v}"
  fi
fi

# Written by subagent-statusline.sh: one status per task id this session.
agents_v=""
agents_file=$state_dir/${session_id}.agents.json
if [[ -n $session_id && -r $agents_file ]]; then
  read a_total a_done a_failed < <(jq -r '[
      length,
      (map(select(. == "completed")) | length),
      (map(select(. == "failed" or . == "killed")) | length)
    ] | @tsv' "$agents_file")
  if (( a_total > 0 )); then
    agents_v="${green}${a_done}${reset}/${a_total} done"
    (( a_failed > 0 )) && agents_v+=" ${dim}·${reset} ${red}${a_failed} failed${reset}"
  fi
fi

# ── Row 3: context │ tokens │ cost │ lines ─────────────────────────────────────
ctx_v=""
if [[ -n $ctx_pct ]]; then
  c=$(level $ctx_pct)
  ctx_v="${c}$(bar $ctx_pct) ${ctx_pct}%${reset} ${dim}$(human $ctx_used)/$(human $ctx_size)${reset}"
fi

# Every API call in the main conversation, cache reads included. A response
# is logged once per content block, so dedupe on the message id.
tok_v=""
if [[ -r $transcript ]]; then
  read tok_in tok_out < <(grep -F '"usage"' "$transcript" | jq -rn '
    [inputs | select(.type == "assistant") | .message | select(.usage) | {id, u: .usage}]
    | unique_by(.id) | map(.u)
    | [ (map(.input_tokens + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)) | add // 0),
        (map(.output_tokens // 0) | add // 0) ]
    | @tsv')
  (( tok_in + tok_out > 0 )) && tok_v="$(human $tok_in) in ${dim}·${reset} $(human $tok_out) out"
fi

cost_v=$(printf '$%.2f' $cost)

lines_v=""
(( added + removed > 0 )) && lines_v="${green}+${added}${reset} ${red}−${removed}${reset}"

# ── Row 4: session │ 5h limit │ 7d limit ──────────────────────────────────────
# Percent of each rolling usage window spent, and when it resets.
limit() {
  [[ -n $1 ]] || return 0
  print -rn -- "$(level $1)$1%${reset}"
  [[ -n $2 ]] && print -rn -- " ${dim}· resets in $(time_left $2)${reset}"
}
rl_5h_v=$(limit "$rl_5h" "$rl_5h_at")
rl_7d_v=$(limit "$rl_7d" "$rl_7d_at")

# ── Render ───────────────────────────────────────────────────────────────────
cells=(
  model   "$model_v"  effort "$effort_v" style "$style_v" mode   "$mode_v"
  dir     "$dir_v"    branch "$branch_v" pr    "$pr_v"    agents "$agents_v"
  context "$ctx_v"    tokens "$tok_v"    cost  "$cost_v"  lines  "$lines_v"
)

row="" n=0
for (( k = 1; k <= ${#cells}; k += 2 )); do
  if (( ++n % ncols == 0 )); then
    print -r -- "$row$(cell ${cells[k]} "${cells[k+1]}" 0)"
    row=""
  else
    row+=$(cell ${cells[k]} "${cells[k+1]}" $cw)
  fi
done

# The title spans the first two columns, the limits take the last two; on
# narrower grids each gets its own row.
title_v=""
case $ncols in
  4)
    [[ -n $title ]] && title_v="${bold}$(clip $(( 2 * cw - lw - 2 )) "$title")${reset}"
    print -r -- "$(cell session "$title_v" $(( 2 * cw )))$(cell '5h limit' "$rl_5h_v" $cw)$(cell '7d limit' "$rl_7d_v" 0)"
    ;;
  2)
    [[ -n $title ]] && title_v="${bold}$(clip $(( 2 * cw - lw - 2 )) "$title")${reset}"
    print -r -- "$(cell session "$title_v" 0)"
    print -r -- "$(cell '5h limit' "$rl_5h_v" $cw)$(cell '7d limit' "$rl_7d_v" 0)"
    ;;
  *)
    [[ -n $title ]] && title_v="${bold}$(clip $vw "$title")${reset}"
    print -r -- "$(cell session "$title_v" 0)"
    print -r -- "$(cell '5h limit' "$rl_5h_v" 0)"
    print -r -- "$(cell '7d limit' "$rl_7d_v" 0)"
    ;;
esac
