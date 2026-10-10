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
  -- Explicit so switching pickers later is a one-line change.
  picker = 'telescope',

  -- Matches ship-pr, so `:Octo pr merge` needs no argument.
  default_merge_method = 'squash',

  -- No nerd font means no devicons provider; no icons beats a column of tofu.
  file_panel = { icons = false },
}

-- Registered here so init.lua stays identical to upstream kickstart.
require('which-key').add { { '<leader>o', group = '[O]cto (GitHub)' } }

local map = function(lhs, rhs, desc) vim.keymap.set('n', '<leader>o' .. lhs, '<cmd>Octo ' .. rhs .. '<cr>', { desc = desc }) end

map('p', 'pr list', '[P]R list')
map('P', 'pr search', '[P]R search (all repos)')
map('i', 'issue list', '[I]ssue list')
map('I', 'issue search', '[I]ssue search (all repos)')
map('c', 'pr checkout', 'PR [C]heckout')
map('d', 'pr changes', 'PR raw unified [D]iff')
map('b', 'pr browser', 'Open PR in [B]rowser')

-- octo's review panel is its own diffview fork, and the only place GitHub comments work.
map('r', 'review start', '[R]eview start')
map('s', 'review submit', 'Review [S]ubmit')
map('R', 'review resume', '[R]eview resume pending')


-- octo hardcodes its review colours; link them to the theme, and relink after :colorscheme.
local function link_octo_diff_colors()
  vim.api.nvim_set_hl(0, 'OctoReviewDiffAddText', { link = 'DiffAdd' })
  vim.api.nvim_set_hl(0, 'OctoReviewDiffDeleteText', { link = 'DiffDelete' })
end

link_octo_diff_colors()
vim.api.nvim_create_autocmd('ColorScheme', {
  callback = link_octo_diff_colors,
  desc = 'Keep octo review diff colours matched to the colorscheme',
})
