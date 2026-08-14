#!/bin/sh
# Runs once per machine on first `chezmoi apply`: ensures Homebrew exists so
# the Brewfile script (run_onchange_brew-bundle.sh) can install the baseline.
command -v brew >/dev/null 2>&1 && exit 0
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
