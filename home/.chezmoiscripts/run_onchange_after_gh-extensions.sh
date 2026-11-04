#!/bin/sh
# gh extensions, pinned. Runs after the package scripts install gh. An installed
# extension is skipped, so bumping a pin needs `gh extension remove` first.
command -v gh >/dev/null 2>&1 || { echo "gh missing: skipping gh extensions" >&2; exit 0; }

gh extension list | grep -q 'drogers0/gh-image' \
    || gh extension install drogers0/gh-image --pin v1.4.1 \
    || echo "gh-image install failed: run 'gh auth login', then 'chezmoi apply'" >&2
