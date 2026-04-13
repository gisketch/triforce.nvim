local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local INFO = vim.log.levels.INFO
local Util = require('triforce.util')
local Config = require('triforce.config')

---@class Triforce
local M = {}

M.close_config = Config.close_window
M.get_stats = require('triforce.tracker').get_stats
M.open_config = Config.open_window
M.toggle_config = Config.toggle_window

---@param opts? TriforceConfig
function M.setup(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  -- Check Neovim version compatibility
  if not Util.vim_has('nvim-0.9') then
    vim.api.nvim_err_writeln('triforce.nvim requires Neovim >= 0.9.0') ---@diagnostic disable-line:deprecated
    return
  end

  if vim.g.loaded_triforce ~= 1 then
    vim.g.loaded_triforce = 1
  end

  Config.setup(opts or {})

  -- Create <Plug> mappings for users to map to their own keys
  vim.keymap.set('n', '<Plug>(TriforceProfile)', M.show_profile, {
    noremap = true,
    silent = true,
    desc = 'Triforce: Show profile',
  })

  require('triforce.levels').setup()
  require('triforce.commands').setup()

  local config = Config.config
  -- Set up keymap if provided
  if config.keymap and config.keymap.show_profile and config.keymap.show_profile ~= '' then
    vim.keymap.set('n', config.keymap.show_profile, M.show_profile, {
      desc = 'Show Triforce Profile',
      silent = true,
      noremap = true,
    })
  end

  if not Config.has_gamification(true) then
    return
  end

  require('triforce.tracker').setup()

  if config.achievements then
    M.new_achievements(config.achievements)
  end

  if config.levels and not vim.tbl_isempty(config.levels) then
    require('triforce.levels').add_levels(config.levels)
  end

  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('TriforceProfile', { clear = true }),
    callback = function()
      require('triforce.ui.profile').setup_highlights()
    end,
  })
end

---Show profile UI
---@param tab? string
function M.show_profile(tab)
  Util.validate({ tab = { tab, { 'string', 'nil' }, true } })
  if not require('triforce.config').has_gamification() then
    return
  end

  local tracker = require('triforce.tracker')
  if not tracker.current_stats then
    tracker.setup()
  end

  local profile = require('triforce.ui.profile')
  local tab_n = (tab and profile.tabs_map[tab]) and profile.tabs_map[tab] or profile.current_tab

  if profile.current_tab ~= tab_n then
    if profile.dimensions.float and profile.dimensions.dim_float then
      profile.cycle_tab(nil, tab_n)
      return
    end
  end
  profile.toggle(tab_n)
end

---Reset all stats (useful for testing)
function M.reset_stats()
  if not require('triforce.config').has_gamification() then
    return
  end

  require('triforce.tracker').reset_stats()
end

---Debug language tracking
function M.debug_languages()
  if not require('triforce.config').has_gamification() then
    return
  end

  require('triforce.tracker').debug_languages()
end

---Force save stats
function M.save_stats()
  if not require('triforce.config').has_gamification() then
    return
  end

  local tracker = require('triforce.tracker')
  if not tracker.current_stats then
    vim.notify('No stats to save!', WARN)
    return
  end

  if tracker.current_stats and require('triforce.stats').save(tracker.current_stats) then
    local path = vim.fn.fnamemodify(tracker.current_stats.db_path, ':~')
    vim.notify(('Stats saved successfully in `%s`'):format(path), INFO)
    return
  end
  error('Failed to save stats!', ERROR)
end

---Debug: Show current XP progress
function M.debug_xp()
  if not require('triforce.config').has_gamification() then
    return
  end

  require('triforce.tracker').debug_xp()
end

---Debug: Test achievement notification
function M.debug_achievement()
  if not require('triforce.config').has_gamification() then
    return
  end

  require('triforce.tracker').debug_achievement()
end

---Debug: Fix level/XP mismatch
function M.debug_fix_level()
  if not require('triforce.config').has_gamification() then
    return
  end

  require('triforce.tracker').debug_fix_level()
end

function M.export_stats()
  if not require('triforce.config').has_gamification() then
    return
  end

  require('triforce.stats').export_stats(require('triforce.tracker').get_stats())
end

---Export stats to JSON
---@param file string
---@param indent? string
function M.export_stats_to_json(file, indent)
  Util.validate({
    file = { file, { 'string' } },
    indent = { indent, { 'string', 'nil' }, true },
  })
  if not require('triforce.config').has_gamification() then
    return
  end

  require('triforce.stats').export_to_json(require('triforce.tracker').get_stats(), file, indent or nil)
end

---Export stats to Markdown
---@param file string
function M.export_stats_to_md(file)
  Util.validate({ file = { file, { 'string' } } })
  if not require('triforce.config').has_gamification() then
    return
  end

  require('triforce.stats').export_to_md(require('triforce.tracker').get_stats(), file)
end

---@param achievements Achievement[]|Achievement
function M.new_achievements(achievements)
  Util.validate({ achievements = { achievements, { 'table' } } })
  if not require('triforce.config').has_gamification() then
    return
  end

  require('triforce.achievement').new_achievements(achievements, require('triforce.tracker').get_stats())
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
