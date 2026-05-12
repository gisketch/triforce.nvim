local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local INFO = vim.log.levels.INFO
local Config = require('triforce.config')
local Levels = require('triforce.levels')
local Stats = require('triforce.stats')
local Tracker = require('triforce.tracker')
local Util = require('triforce.util')

---@class Triforce
local M = {}

M.get_stats = Tracker.get_stats
M.open_config = Config.open_window

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

  local config = Config.config
  Levels.setup(config.override_levels)
  require('triforce.commands').setup()

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

  Tracker.setup()

  M.new_achievements(config.achievements or {})

  if config.levels and not vim.tbl_isempty(config.levels) then
    Levels.add_levels(config.levels)
  end

  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('TriforceProfile', { clear = true }),
    desc = 'Sync Triforce with colorscheme changes',
    callback = function()
      require('triforce.ui.profile').setup_highlights()
    end,
  })
end

---Show profile UI
---@param tab? string
function M.show_profile(tab)
  Util.validate({ tab = { tab, { 'string', 'nil' }, true } })
  if not Config.has_gamification() then
    return
  end

  if not Tracker.current_stats then
    Tracker.setup()
  end

  local Profile = require('triforce.ui.profile')
  local tab_n = (tab and Profile.tabs_map[tab]) and Profile.tabs_map[tab] or Profile.current_tab
  if Profile.current_tab ~= tab_n and Profile.dimensions.float and Profile.dimensions.dim_float then
    Profile.cycle_tab(nil, tab_n)
    return
  end
  Profile.toggle(tab_n)
end

---Reset all stats (useful for testing)
function M.reset_stats()
  if not Config.has_gamification() then
    return
  end
  Tracker.reset_stats()
end

---Debug language tracking
function M.debug_languages()
  if not Config.has_gamification() then
    return
  end
  Tracker.debug_languages()
end

---Force save stats
function M.save_stats()
  if not Config.has_gamification() then
    return
  end
  if not Tracker.current_stats then
    vim.notify('No stats to save!', WARN)
    return
  end
  if not (Tracker.current_stats and Stats.save(Tracker.current_stats)) then
    vim.notify('Failed to save stats!', ERROR)
    return
  end
  vim.notify(('Stats saved successfully in `%s`'):format(vim.fn.fnamemodify(Tracker.current_stats.db_path, ':~')), INFO)
end

---Debug: Show current XP progress
function M.debug_xp()
  if not Config.has_gamification() then
    return
  end
  Tracker.debug_xp()
end

---Debug: Test achievement notification
function M.debug_achievement()
  if not Config.has_gamification() then
    return
  end
  Tracker.debug_achievement()
end

---Debug: Fix level/XP mismatch
function M.debug_fix_level()
  if not Config.has_gamification() then
    return
  end
  Tracker.debug_fix_level()
end

function M.export_stats()
  if not Config.has_gamification() then
    return
  end
  Stats.export_stats(Tracker.get_stats())
end

---Export stats to JSON
---@param file string
---@param indent? string
function M.export_stats_to_json(file, indent)
  Util.validate({
    file = { file, { 'string' } },
    indent = { indent, { 'string', 'nil' }, true },
  })
  if not Config.has_gamification() then
    return
  end

  Stats.export_to_json(Tracker.get_stats(), file, indent or nil)
end

---Export stats to Markdown
---@param file string
function M.export_stats_to_md(file)
  Util.validate({ file = { file, { 'string' } } })
  if not Config.has_gamification() then
    return
  end

  Stats.export_to_md(Tracker.get_stats(), file)
end

---@param achievements Achievement[]|Achievement
function M.new_achievements(achievements)
  Util.validate({ achievements = { achievements, { 'table' } } })
  if not Config.has_gamification() then
    return
  end

  require('triforce.achievement').new_achievements(achievements, Tracker.get_stats())
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
