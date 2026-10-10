-- Tab-per-repo workspaces.
--
-- Neovim anchors `:pwd` to the directory it launched from, and that one
-- directory is what telescope searches, what neo-tree displays, and what the
-- LSP treats as the project root. Switching repos therefore meant `:qa` and a
-- fresh `nvim` in the other checkout.
--
-- `:tcd` sets a directory for a *single* tab page, so a tab becomes a repo:
-- telescope, neo-tree, and `:pwd` all re-scope when you move between tabs. One
-- long-lived nvim, one tab per repo, no quitting.
--
-- The cost is that every open repo keeps its own LSP clients alive, so
-- `<leader>wq` closes a tab when you're done with that repo.

local M = {}

local uv = vim.uv or vim.loop

local SEARCH_ROOTS = { '~/Repos', '~/worktrees' }

local function is_dir(path)
  local stat = uv.fs_stat(path)
  return stat ~= nil and stat.type == 'directory'
end

-- Existence, not type: a worktrunk worktree has a .git file, not a directory.
local function is_repo(path) return uv.fs_stat(vim.fs.joinpath(path, '.git')) ~= nil end

local function subdirs(path)
  local out = {}
  local ok, iter = pcall(vim.fs.dir, path, { depth = 1 })
  if not ok then return out end
  for name, type in iter do
    local child = vim.fs.joinpath(path, name)
    -- vim.fs.dir reports symlinked directories as 'link', so stat them.
    if name:sub(1, 1) ~= '.' and (type == 'directory' or is_dir(child)) then out[#out + 1] = child end
  end
  return out
end

-- Projects under root: each child, or the repos inside a child that contains repos.
local function collect(root)
  local found = {}
  for _, child in ipairs(subdirs(root)) do
    if is_repo(child) then
      found[#found + 1] = child
    else
      local repo_children = vim.tbl_filter(is_repo, subdirs(child))
      if #repo_children > 0 then
        vim.list_extend(found, repo_children)
      else
        found[#found + 1] = child
      end
    end
  end
  return found
end

-- Keeps the parent segment so worktrees of one repo stay distinguishable.
local function display_name(path)
  local name = vim.fn.fnamemodify(path, ':~')
  return (name:gsub('^~/', ''):gsub('^Repos/', ''))
end

function M.projects()
  local seen, out = {}, {}
  for _, root in ipairs(SEARCH_ROOTS) do
    local expanded = vim.fs.normalize(root)
    if is_dir(expanded) then
      for _, path in ipairs(collect(expanded)) do
        if not seen[path] then
          seen[path] = true
          out[#out + 1] = { path = path, name = display_name(path) }
        end
      end
    end
  end
  -- Alphabetical: directory mtimes don't track recent edits.
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

-- Tab-local cwd, or the global one for a tab that never ran :tcd.
local function tab_cwd(tabnr)
  local ok, cwd = pcall(vim.fn.getcwd, -1, tabnr)
  return ok and vim.fs.normalize(cwd) or nil
end

local function find_tab(path)
  for _, tabid in ipairs(vim.api.nvim_list_tabpages()) do
    local tabnr = vim.api.nvim_tabpage_get_number(tabid)
    if tab_cwd(tabnr) == path then return tabid end
  end
  return nil
end

-- A bare nvim tab with no :tcd yet, safe to reuse for the first repo picked.
local function tab_is_scratch(tabid)
  local tabnr = vim.api.nvim_tabpage_get_number(tabid)
  if vim.fn.haslocaldir(-1, tabnr) ~= 0 then return false end

  local wins = vim.api.nvim_tabpage_list_wins(tabid)
  if #wins ~= 1 then return false end
  local buf = vim.api.nvim_win_get_buf(wins[1])
  return vim.api.nvim_buf_get_name(buf) == ''
    and not vim.bo[buf].modified
    and vim.api.nvim_buf_line_count(buf) == 1
    and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ''
end

--- Open a project in its own tab, or jump to the tab already holding it.
function M.open(path)
  path = vim.fs.normalize(path)
  if not is_dir(path) then
    vim.notify('workspaces: not a directory: ' .. path, vim.log.levels.ERROR)
    return
  end

  local existing = find_tab(path)
  if existing then
    vim.api.nvim_set_current_tabpage(existing)
    return
  end

  if not tab_is_scratch(vim.api.nvim_get_current_tabpage()) then vim.cmd 'tabnew' end
  vim.cmd.tcd(vim.fn.fnameescape(path))

  -- Open the file picker: reaching a file is why you switched.
  local ok, builtin = pcall(require, 'telescope.builtin')
  if ok then builtin.find_files() end
end

--- Telescope picker over every discovered project.
function M.pick()
  local projects = M.projects()
  if #projects == 0 then
    vim.notify('workspaces: no projects found under ' .. table.concat(SEARCH_ROOTS, ', '), vim.log.levels.WARN)
    return
  end

  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'
  local conf = require('telescope.config').values

  pickers
    .new({}, {
      prompt_title = 'Repos',
      finder = finders.new_table {
        results = projects,
        entry_maker = function(entry)
          return { value = entry.path, display = entry.name, ordinal = entry.name }
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(bufnr)
          if selection then M.open(selection.value) end
        end)
        return true
      end,
    })
    :find()
end

--- Close the current tab, releasing that repo's LSP clients with it.
function M.close()
  if #vim.api.nvim_list_tabpages() == 1 then
    vim.notify('workspaces: last tab — nothing to close', vim.log.levels.WARN)
    return
  end
  vim.cmd 'tabclose'
end

-- Diffview gets its own tab; label it rather than repeat the repo name.
local function tab_is_diffview(tabid)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabid)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_get_name(buf):match '^diffview://' then return true end
    if vim.bo[buf].filetype:match '^Diffview' then return true end
  end
  return false
end

local function tab_modified(tabid)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabid)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].modified then return true end
  end
  return false
end

local function tab_label(tabid, tabnr)
  if tab_is_diffview(tabid) then return 'diff' end

  local cwd = tab_cwd(tabnr)
  if not cwd then return '[no name]' end

  -- A worktree's basename is the branch, so prefix the repo.
  local label = vim.fs.basename(cwd)
  if cwd:match '/worktrees/' then label = vim.fs.basename(vim.fs.dirname(cwd)) .. ':' .. label end
  if #label > 24 then label = label:sub(1, 23) .. '…' end
  return label
end

--- Renders `vim.o.tabline`; public because the option references it by name.
function M.tabline()
  local current = vim.api.nvim_get_current_tabpage()
  local parts = {}
  for _, tabid in ipairs(vim.api.nvim_list_tabpages()) do
    local tabnr = vim.api.nvim_tabpage_get_number(tabid)
    parts[#parts + 1] = table.concat {
      tabid == current and '%#TabLineSel#' or '%#TabLine#',
      -- `%<nr>T` makes the label clickable and closes the region with `%T`.
      '%' .. tabnr .. 'T',
      ' ' .. tabnr .. ' ',
      tab_label(tabid, tabnr),
      tab_modified(tabid) and ' +' or '',
      ' ',
    }
  end
  return table.concat(parts) .. '%#TabLineFill#%T'
end

vim.o.tabline = [[%!v:lua.require('custom.plugins.workspaces').tabline()]]
-- Show the tabline only once a second tab exists.
vim.o.showtabline = 1

vim.keymap.set('n', '<leader>ww', M.pick, { desc = '[W]orkspace: s[w]itch repo' })
vim.keymap.set('n', '<leader>wq', M.close, { desc = '[W]orkspace: [q]uit this tab' })
vim.keymap.set('n', ']t', '<cmd>tabnext<cr>', { desc = 'Next tab' })
vim.keymap.set('n', '[t', '<cmd>tabprevious<cr>', { desc = 'Previous tab' })

-- <leader>1..9 jump to a tab; built-in g<Tab> returns to the last one.
for i = 1, 9 do
  vim.keymap.set('n', '<leader>' .. i, i .. 'gt', { desc = 'Go to tab ' .. i })
end

return M
