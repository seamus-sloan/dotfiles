#!/bin/bash
# Reproduces every planted defect in the workspaces-session-restore fixture, so
# the answer key is evidence rather than intent. Usage:
#
#   bash verify-seeds.sh <fixture worktree>
#
# Every line should print REPRODUCED. Each seed runs in its own headless nvim
# with a throwaway HOME and state file.

set -u

FIX=$(cd "$1" && pwd)
NVIM_DIR="$FIX/home/dot_config/exact_nvim"
PLUGINS="$NVIM_DIR/lua/custom/plugins"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

seed() { if [ "$2" = yes ]; then echo "REPRODUCED      $1${3:+ — $3}"; else echo "not-reproduced  $1${3:+ — $3}"; fi; }

# Runs a Lua snippet against the fixture module in a fresh nvim. The prelude
# builds HOME/Repos/{alpha,beta,gamma} and exposes `ws`, `repo`, `write_state`,
# `read_state`, `settle`, and `out` (print a result line).
lua_seed() {
  cat >"$T/seed.lua" <<EOF
vim.opt.rtp:prepend('$NVIM_DIR')
local home = vim.fn.tempname(); vim.fn.mkdir(home, 'p'); home = vim.uv.fs_realpath(home)
vim.env.HOME = home
local state_path = home .. '/workspaces.json'
vim.g.workspaces_state_path = state_path
function repo(name) local p = home .. '/Repos/' .. name; vim.fn.mkdir(p .. '/.git', 'p'); return p end
function write_state(s) local f = assert(io.open(state_path, 'w')); f:write(vim.json.encode(s)); f:close() end
function read_state() local f = io.open(state_path, 'r'); if not f then return nil end local s = vim.json.decode(f:read '*a'); f:close(); return s end
function settle() vim.wait(150) end
function out(s) io.stdout:write('SEED:' .. s .. '\n') end
alpha, beta, gamma = repo 'alpha', repo 'beta', repo 'gamma'
$2
EOF
  nvim --headless -l "$T/seed.lua" 2>&1 | sed -n 's/^SEED://p' | tail -1
}

r=$(lua_seed C1 "ws = require 'custom.plugins.workspaces'
local ok, err = pcall(ws.projects)
out((ok and 'no' or 'yes') .. '|' .. tostring(err))")
seed "C1 first run with no state file: projects() errors" "${r%%|*}" "${r#*|}"

r=$(lua_seed C2 "write_state { version = 1, recent = {}, tabs = {} }
ws = require 'custom.plugins.workspaces'
local last
for i = 1, 11 do last = repo(('p%02d'):format(i)); ws.open(last, { picker = false }); settle() end
local recent = read_state().recent
out(((recent[1] ~= last) and 'yes' or 'no') .. '|newest ' .. vim.fs.basename(last) .. ', recent[1] ' .. vim.fs.basename(recent[1] or '?'))")
seed "C2 once full, the project just opened is dropped" "${r%%|*}" "${r#*|}"

r=$(lua_seed C3 "write_state { version = 1, recent = {}, tabs = {} }
ws = require 'custom.plugins.workspaces'
_G.tab_modified = function() return false end -- step past C4
local ok, err = pcall(ws.close)
out(((not ok and tostring(err):match 'E784') and 'yes' or 'no') .. '|' .. tostring(err))")
seed "C3 <leader>wq on the last tab raises E784" "${r%%|*}" "${r#*|}"

r=$(lua_seed C4 "write_state { version = 1, recent = {}, tabs = {} }
ws = require 'custom.plugins.workspaces'
vim.cmd 'tabnew'
local ok, err = pcall(ws.close)
out(((not ok and tostring(err):match 'tab_modified') and 'yes' or 'no') .. '|' .. tostring(err))")
seed "C4 close() calls tab_modified before it is defined" "${r%%|*}" "${r#*|}"

r=$(lua_seed C5 "write_state { version = 1, recent = {}, tabs = { home .. '/Repos/deleted', alpha, beta } }
ws = require 'custom.plugins.workspaces'
ws.restore()
local n = 0
for _, t in ipairs(vim.api.nvim_list_tabpages()) do
  if vim.fn.haslocaldir(-1, vim.api.nvim_tabpage_get_number(t)) == 1 then n = n + 1 end
end
out(((n < 2) and 'yes' or 'no') .. '|restored ' .. n .. ' of 2 existing tabs')")
seed "C5 a missing first path stops restore of the rest" "${r%%|*}" "${r#*|}"

r=$(lua_seed C6 "write_state { version = 1, recent = {}, tabs = {} }
local target = repo 'u-sloan-foo'
ws = require 'custom.plugins.workspaces'
local said
vim.notify = function(msg) said = msg end
vim.cmd 'Workspace sloan-foo'
out(((vim.fn.getcwd(-1, 0) ~= target) and 'yes' or 'no') .. '|' .. tostring(said))")
seed "C6 a hyphenated partial name never matches" "${r%%|*}" "${r#*|}"

r=$(lua_seed C7 "write_state { version = 1, recent = {}, tabs = { alpha, beta, gamma } }
ws = require 'custom.plugins.workspaces'
ws.restore()
settle()
local recent = read_state().recent
out(((#recent < 3) and 'yes' or 'no') .. '|recent after restoring 3 tabs: ' .. #recent)")
seed "C7 overlapping saves during restore lose updates" "${r%%|*}" "${r#*|}"

# C8: custom/plugins/init.lua requires every .lua file beside it at startup.
loader=$(cd "$PLUGINS" && for f in *.lua; do case "$f" in init.lua) ;; *) echo "${f%.lua}" ;; esac; done | tr '\n' ' ')
r=$(nvim --headless --clean --cmd "set rtp^=$NVIM_DIR" -c "lua require 'custom.plugins.workspaces_spec'" -c "lua io.stdout:write('STARTUP-CONTINUED\n')" -c 'qa!' 2>&1 | tail -1)
if printf '%s' "$loader" | grep -q workspaces_spec && [ "$r" != STARTUP-CONTINUED ]; then c8=yes; else c8=no; fi
seed "C8 the startup loader would require the test suite, which exits nvim" "$c8" "loader requires: $loader"

grep -q "<leader>wr" "$PLUGINS/workspaces.lua" && c9=no || c9=yes
seed "C9 no <leader>wr keymap" "$c9"

(cd "$FIX" && nvim --headless -l "$PLUGINS/workspaces_spec.lua" >/dev/null 2>&1) && c10=yes || c10=no
seed "C10 the spec passes while C2 drops the newest project" "$c10"

grep -q "local function migrate" "$PLUGINS/workspaces.lua" && c11=yes || c11=no
seed "C11 migrate() for a format with one version" "$c11"
