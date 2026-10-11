#!/bin/bash
# Shared by run.sh and grade.sh. Source it after fixture.env.

# fixture_repo <fixture dir>: prints the path of the fixture's checkout,
# creating it on first use.
#
# The checkout is a standalone clone of this repo cut off at $BASE, with
# $BRANCH holding fixture.patch, rather than a worktree of this repo. A
# worktree shares refs with the repo that holds this harness, so a reviewer's
# `git log --all` reaches the answer keys; this clone has no ref past $BASE, and
# no objects past it either. The path is neutral on purpose: a directory named
# after the eval would tell the reviewer what it's looking at.
fixture_repo() {
  local fdir=$1 repo fx wt
  repo=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --path-format=absolute --git-common-dir)
  repo=$(dirname "$repo")
  fx="${TMPDIR:-/tmp}"
  fx="${fx%/}/fx-$(printf '%s' "$BRANCH" | shasum | cut -c1-8)"
  wt="$fx/$(basename "$repo")"
  if [ ! -d "$wt/.git" ]; then
    rm -rf "$fx" && mkdir -p "$fx"
    git clone -q --no-local --single-branch --branch main --no-tags "$repo" "$wt"
    git -C "$wt" checkout -q -B "$BRANCH" "$BASE"
    git -C "$wt" branch -q -D main
    git -C "$wt" update-ref refs/remotes/origin/main "$BASE"
    git -C "$wt" remote set-url origin "$(git -C "$repo" remote get-url origin)"
    git -C "$wt" reflog expire --expire=now --all
    git -C "$wt" gc -q --prune=now
    git -C "$wt" -c core.hooksPath=/dev/null am -q "$fdir/fixture.patch"
    git -C "$wt" branch -q --set-upstream-to=origin/main
  fi
  printf '%s\n' "$wt"
}

# fixture_check <checkout> <fixture dir>: fails unless the checkout is clean,
# holds exactly fixture.patch on top of $BASE, and has no refs beyond it.
fixture_check() {
  local wt=$1 fdir=$2 want have
  [ -z "$(git -C "$wt" status --porcelain)" ] || { echo "fixture checkout is dirty: $wt" >&2; return 1; }
  want=$(git patch-id --stable <"$fdir/fixture.patch" | cut -d' ' -f1)
  have=$(git -C "$wt" diff "$BASE"...HEAD | git patch-id --stable | cut -d' ' -f1)
  [ "$want" = "$have" ] || { echo "fixture checkout doesn't match fixture.patch: $wt" >&2; return 1; }
  [ "$(git -C "$wt" rev-list --all | wc -l)" -eq "$(($(git -C "$wt" rev-list "$BASE" | wc -l) + $(git -C "$wt" rev-list "$BASE"..HEAD | wc -l)))" ] \
    || { echo "fixture checkout has refs beyond the fixture: $wt" >&2; return 1; }
}
