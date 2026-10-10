-- Markdown rendered in the buffer you are editing.
--
-- This is not a preview pane. render-markdown draws over the real buffer with
-- extmarks -- headings get a coloured background, fenced code gets a block
-- background, tables get box-drawing borders, `- [ ]` becomes a checkbox -- so
-- the text stays editable underneath. `anti_conceal` (on by default) un-renders
-- whichever line the cursor is on, which is what makes editing rendered
-- markdown bearable: you read the pretty version and edit the raw version
-- without ever toggling a mode.
--
-- Everything here is extmarks and highlights, i.e. ordinary coloured text. It
-- needs no terminal graphics protocol, so it works the same in Warp as it would
-- in Kitty. (Real inline *images* would need `image.nvim` and a terminal that
-- speaks the Kitty graphics protocol -- that is the part Warp cannot do.)
--
-- `markdown` and `markdown_inline` are already in the treesitter parser list in
-- init.lua, which is the only hard dependency.

vim.pack.add { 'https://github.com/MeanderingProgrammer/render-markdown.nvim' }

-- Without a grammar bound to the octo filetype, render-markdown renders nothing.
vim.treesitter.language.register('markdown', 'octo')

-- Plain Unicode icons unless a nerd font is enabled.
local nerd = vim.g.have_nerd_font

require('render-markdown').setup {
  -- octo's PR descriptions and review comments are markdown too.
  file_types = { 'markdown', 'octo' },

  heading = {
    -- Icon over the #s, so headings stay aligned with body text.
    position = 'overlay',
    icons = nerd and { '󰲡 ', '󰲣 ', '󰲥 ', '󰲧 ', '󰲩 ', '󰲫 ' } or { '◉ ', '○ ', '◈ ', '◇ ', '▪ ', '▫ ' },
    width = 'full',
  },

  code = {
    -- The background is what makes code easy to find in a long PR description.
    style = 'full',
    width = 'block',
    min_width = 40,
    left_pad = 2,
    right_pad = 2,
    border = 'thin',
    -- Both of these resolve Nerd Font glyphs through mini.icons.
    language_icon = nerd,
    sign = nerd,
  },

  checkbox = {
    unchecked = { icon = nerd and '󰄱 ' or '☐ ' },
    checked = { icon = nerd and '󰱒 ' or '☑ ' },
  },

  -- Nerd Font glyphs that would collide with gitsigns anyway.
  sign = { enabled = nerd },

  -- No latex parser or renderer installed; on, it only adds healthcheck warnings.
  latex = { enabled = false },

  indent = { enabled = true },
}

vim.keymap.set('n', '<leader>tm', '<cmd>RenderMarkdown toggle<cr>', { desc = '[T]oggle [M]arkdown rendering' })
