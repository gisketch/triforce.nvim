local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local INFO = vim.log.levels.INFO
local util = require('triforce.util')
local config_mod = require('triforce.config')

---@class Triforce
local Triforce = {
  get_stats = require('triforce.tracker').get_stats,
  open_config = config_mod.open_window,
  close_config = config_mod.close_window,
  toggle_config = config_mod.toggle_window,
}

---@param opts TriforceConfig
---@overload fun()
function Triforce.setup(opts)
  util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  -- Check Neovim version compatibility
  if not util.vim_has('nvim-0.9') then
    vim.api.nvim_err_writeln('triforce.nvim requires Neovim >= 0.9.0') ---@diagnostic disable-line:deprecated
    return
  end

  if vim.g.loaded_triforce ~= 1 then
    vim.g.loaded_triforce = 1
  end

  local config_module = require('triforce.config')
  config_module.setup(opts or {})

  -- Create <Plug> mappings for users to map to their own keys
  vim.keymap.set('n', '<Plug>(TriforceProfile)', Triforce.show_profile, {
    noremap = true,
    silent = true,
    desc = 'Triforce: Show profile',
  })

  require('triforce.stats').setup()
  require('triforce.levels').setup()
  require('triforce.commands').setup()

  local config = config_module.config
  -- Set up keymap if provided
  if config.keymap and config.keymap.show_profile and config.keymap.show_profile ~= '' then
    vim.keymap.set('n', config.keymap.show_profile, Triforce.show_profile, {
      desc = 'Show Triforce Profile',
      silent = true,
      noremap = true,
    })
  end

  if not config_module.has_gamification(true) then
    return
  end

  require('triforce.tracker').setup()

  if config.achievements then
    Triforce.new_achievements(config.achievements)
  end

  if config.levels and not vim.tbl_isempty(config.levels) then
    require('triforce.levels').add_levels(config.levels)
  end

  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('TriforceProfile', { clear = true }),
    callback = function()
      local Profile = require('triforce.ui.profile')
      Profile.setup_highlights()
    end,
  })
end

---Show profile UI
function Triforce.show_profile()
  if not require('triforce.config').has_gamification() then
    return
  end

  local tracker = require('triforce.tracker')
  if not tracker.current_stats then
    tracker.setup()
  end

  require('triforce.ui.profile').toggle()
end

---Reset all stats (useful for testing)
function Triforce.reset_stats()
  if not require('triforce.config').has_gamification() then
    return
  end

  require('triforce.tracker').reset_stats()
end

---Debug language tracking
function Triforce.debug_languages()
  if not require('triforce.config').has_gamification() then
    return
  end

  require('triforce.tracker').debug_languages()
end

---Force save stats
function Triforce.save_stats()
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
function Triforce.debug_xp()
  if not require('triforce.config').has_gamification() then
    return
  end

  require('triforce.tracker').debug_xp()
end

---Debug: Test achievement notification
function Triforce.debug_achievement()
  if not require('triforce.config').has_gamification() then
    return
  end

  require('triforce.tracker').debug_achievement()
end

---Debug: Fix level/XP mismatch
function Triforce.debug_fix_level()
  if not require('triforce.config').has_gamification() then
    return
  end

  require('triforce.tracker').debug_fix_level()
end

function Triforce.export_stats()
  if not require('triforce.config').has_gamification() then
    return
  end

  require('triforce.stats').export_stats(require('triforce.tracker').get_stats())
end

---Export stats to JSON
---@param file string
---@param indent string
---@overload fun(file: string)
function Triforce.export_stats_to_json(file, indent)
  util.validate({
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
function Triforce.export_stats_to_md(file)
  util.validate({ file = { file, { 'string' } } })
  if not require('triforce.config').has_gamification() then
    return
  end

  require('triforce.stats').export_to_md(require('triforce.tracker').get_stats(), file)
end

---@param achievements Achievement[]|Achievement
---@overload fun(achievements: Achievement)
---@overload fun(achievements: Achievement[])
function Triforce.new_achievements(achievements)
  util.validate({ achievements = { achievements, { 'table' } } })
  if not require('triforce.config').has_gamification() then
    return
  end

  require('triforce.achievement').new_achievements(achievements, require('triforce.tracker').get_stats())
end

return Triforce
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
