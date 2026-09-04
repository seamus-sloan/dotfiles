-- GitHub pull requests and issues, inside nvim.
--
-- octo turns a PR into a set of ordinary buffers: the description and comment
-- threads are markdown buffers you edit and `:w` to post, and the review itself
-- runs through diffview -- the same file panel and side-by-side diff already
-- bound under `<leader>g`. Line comments, threaded replies, approving or
-- requesting changes, and submitting the review all happen without leaving the
-- editor.
--
-- Auth piggybacks on the `gh` CLI, so there is no token to configure here; if
-- `gh auth status` works, octo works.
--
-- Pairs with render-markdown.lua, which lists `octo` in its `file_types` so
-- these buffers render as formatted markdown rather than raw `###` and
-- backticks. That is most of what makes a terminal PR review readable.
--
-- Dependencies (plenary, telescope) are already installed by init.lua, which
-- runs before this directory is loaded.

vim.pack.add { 'https://github.com/pwntester/octo.nvim' }

require('octo').setup {
  -- Telescope is the picker already configured in init.lua; octo defaults to
  -- telescope too, but naming it means a future switch to fzf-lua or snacks is
  -- a one-line change here rather than a debugging session.
  picker = 'telescope',

  -- Matches how PRs actually get merged in these repos (see the ship-pr skill),
  -- so `:Octo pr merge` does the right thing without an argument.
  default_merge_method = 'squash',

  -- init.lua only loads mini.icons when `vim.g.have_nerd_font` is set, and it is
  -- not, so nothing provides the `nvim-web-devicons` interface octo's file panel
  -- expects. Asking for no icons is better than rendering a column of tofu.
  file_panel = { icons = false },
}

-- Registered here rather than in init.lua's which-key `spec` table: everything
-- under lua/custom/plugins is ours, while init.lua tracks upstream kickstart
-- and is better left unmodified. which-key is set up earlier in init.lua, so it
-- is available by the time this file runs.
require('which-key').add { { '<leader>o', group = '[O]cto (GitHub)' } }

local map = function(lhs, rhs, desc) vim.keymap.set('n', '<leader>o' .. lhs, '<cmd>Octo ' .. rhs .. '<cr>', { desc = desc }) end

map('p', 'pr list', '[P]R list')
map('P', 'pr search', '[P]R search (all repos)')
map('i', 'issue list', '[I]ssue list')
map('I', 'issue search', '[I]ssue search (all repos)')
map('c', 'pr checkout', 'PR [C]heckout')
map('d', 'pr changes', 'PR raw unified [D]iff')
map('b', 'pr browser', 'Open PR in [B]rowser')

-- `<leader>od` is a plain `gh pr diff` dumped into a scratch buffer -- useful
-- for a quick scan, but it is not a review UI and has no file panel.
--
-- Note that octo does NOT use diffview.nvim. `lua/octo/reviews/` is its own
-- copy, whose header says it is "heavily derived from diffview.nvim"; it even
-- reuses diffview's highlight-group names while ignoring diffview's config. So
-- the review panel below only resembles the one on `<leader>gb`.
--
-- To review in real diffview instead: `<leader>oc` to check the branch out,
-- then `<leader>gb`. That gets the familiar UI, at the cost of not being able
-- to leave GitHub comments -- commenting only works in octo's own panel.
--
-- Review is a three-step flow: `start` opens octo's file panel, you leave
-- comments as you walk the files, then `submit` prompts for approve / request
-- changes / comment. `resume` picks up a review left pending on GitHub.
map('r', 'review start', '[R]eview start')
map('s', 'review submit', 'Review [S]ubmit')
map('R', 'review resume', '[R]eview resume pending')


-- octo hardcodes its review-diff emphasis colours (ui/colors.lua defines
-- `ReviewDiffAddText` / `ReviewDiffDeleteText` as fixed dark green and dark red
-- rather than reading the colorscheme), so they clash with one_monokai's own
-- diff palette. Linking them at the colorscheme's diff groups puts the whole
-- review back on one palette, and keeps it right if the colorscheme changes.
--
-- The autocmd is not belt-and-braces: `:colorscheme` clears every highlight
-- group, and octo registers no ColorScheme handler of its own, so without this
-- its groups would simply disappear on a theme switch.
local function link_octo_diff_colors()
  vim.api.nvim_set_hl(0, 'OctoReviewDiffAddText', { link = 'DiffAdd' })
  vim.api.nvim_set_hl(0, 'OctoReviewDiffDeleteText', { link = 'DiffDelete' })
end

link_octo_diff_colors()
vim.api.nvim_create_autocmd('ColorScheme', {
  callback = link_octo_diff_colors,
  desc = 'Keep octo review diff colours matched to the colorscheme',
})
