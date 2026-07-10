local Util = require('triforce.util')

---@class Triforce
---@field achievement Triforce.Achievements
---@field commands Triforce.Commands
---@field config Triforce.Config
---@field get_stats fun(): stats: Stats|nil
---@field health Triforce.Health
---@field languages Triforce.Languages
---@field levels Triforce.Levels
---@field lualine Triforce.Lualine
---@field open_config function
---@field random_stats Triforce.RandomStats
---@field stats Triforce.Stats
---@field tracker Triforce.Tracker
---@field ui Triforce.Ui
---@field util Triforce.Util
local M = {}

---@param opts? TriforceConfig
function M.setup(opts)
  -- Check Neovim version compatibility
  if not Util.vim_has('nvim-0.9') then
    vim.api.nvim_err_writeln('triforce.nvim requires Neovim >= 0.9.0') ---@diagnostic disable-line:deprecated
    return
  end
  if vim.g.loaded_triforce ~= 1 then
    vim.g.loaded_triforce = 1
  end

  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  local Config = require('triforce.config')
  Config.setup(opts or {})

  -- Create <Plug> mappings for users to map to their own keys
  vim.keymap.set('n', '<Plug>(TriforceProfile)', M.show_profile, {
    noremap = true,
    silent = true,
    desc = 'Triforce: Show profile',
  })

  require('triforce.levels').setup(Config.get().override_levels)
  require('triforce.commands').setup()

  ---@diagnostic disable:undefined-field
  -- Set up keymap if provided
  if Config.get().keymap and Config.get().keymap.show_profile and Config.get().keymap.show_profile ~= '' then
    vim.keymap.set(
      'n',
      Config.get().keymap.show_profile,
      M.show_profile,
      { desc = 'Show Triforce Profile', noremap = true }
    )
  end
  ---@diagnostic enable:undefined-field

  if not Config.has_gamification(true) then
    return
  end

  require('triforce.tracker').setup()

  M.new_achievements(Config.get().achievements or {})

  if Config.get().levels and not vim.tbl_isempty(Config.get().levels) then
    require('triforce.levels').add_levels(Config.get().levels)
  end

  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('TriforceProfile', { clear = true }),
    desc = 'Sync Triforce with colorscheme changes',
    callback = function()
      require('triforce.ui').profile.setup_highlights()
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

  local Tracker = require('triforce.tracker')
  if not Tracker.current_stats then
    Tracker.setup()
  end

  local UI = require('triforce.ui')
  local tab_n = (tab and UI.profile.tabs_map[tab]) and UI.profile.tabs_map[tab] or UI.profile.current_tab
  if UI.profile.current_tab ~= tab_n and UI.profile.dimensions.float and UI.profile.dimensions.dim_float then
    UI.profile.cycle_tab(nil, tab_n)
    return
  end
  UI.profile.toggle(tab_n)
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
  local Tracker = require('triforce.tracker')
  if not Tracker.current_stats then
    vim.notify('No stats to save!', vim.log.levels.WARN)
    return
  end
  if not (Tracker.current_stats and require('triforce.stats').save(Tracker.current_stats)) then
    vim.notify('Failed to save stats!', vim.log.levels.ERROR)
    return
  end
  vim.notify(
    ('Stats saved successfully in `%s`'):format(vim.fn.fnamemodify(Tracker.current_stats.db_path, ':~')),
    vim.log.levels.INFO
  )
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

local Triforce = setmetatable(M, { ---@type Triforce
  ---@param self Triforce
  ---@param k string|integer
  __index = function(self, k)
    if Util.mod_exists('triforce.' .. k) then
      return require('triforce.' .. k)
    end
    if k == 'get_stats' then
      return self.tracker.get_stats
    end
    if k == 'open_config' then
      return self.config.open_window
    end
    return rawget(self, k) or nil
  end,
})

return Triforce
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
