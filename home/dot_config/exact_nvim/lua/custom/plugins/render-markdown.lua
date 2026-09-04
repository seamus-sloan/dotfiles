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

-- render-markdown's out-of-the-box icons are Nerd Font glyphs, and init.lua
-- sets `vim.g.have_nerd_font = false` -- so with the defaults every heading and
-- checkbox would come out as a tofu box. Pick plain Unicode when the flag is
-- off, and the nicer glyphs automatically if it is ever turned on.
local nerd = vim.g.have_nerd_font

require('render-markdown').setup {
  -- `octo` is the payoff for pairing this with octo.nvim: PR descriptions and
  -- review comments are markdown buffers, so they render here too instead of
  -- showing raw `###` and backticks.
  file_types = { 'markdown', 'octo' },

  heading = {
    -- `position = 'overlay'` writes the icon over the `#` characters rather
    -- than pushing the text right, so headings stay aligned with body text.
    position = 'overlay',
    icons = nerd and { '󰲡 ', '󰲣 ', '󰲥 ', '󰲧 ', '󰲩 ', '󰲫 ' } or { '◉ ', '○ ', '◈ ', '◇ ', '▪ ', '▫ ' },
    -- Full-width background bars. 'block' would stop the bar at the end of the
    -- heading text, which is tidier in a narrow split but much less striking.
    width = 'full',
  },

  code = {
    -- 'full' draws both the language label and the block background. The
    -- background is the part that actually helps you find code in a long PR
    -- description.
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

  -- Gutter signs are Nerd Font glyphs, and they collide with the gitsigns
  -- column anyway.
  sign = { enabled = nerd },

  -- No `latex` treesitter parser installed and no `utftex`/`latex2text` binary
  -- to render with, so leaving this on only produces healthcheck warnings.
  latex = { enabled = false },

  -- Indent body text to match the depth of the heading above it, so a document
  -- gets visible structure rather than everything sitting flush left.
  indent = { enabled = true },
}

vim.keymap.set('n', '<leader>tm', '<cmd>RenderMarkdown toggle<cr>', { desc = '[T]oggle [M]arkdown rendering' })
