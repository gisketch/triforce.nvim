local Util = require('triforce.util')

---@class Triforce
---@field achievement Triforce.Achievements
---@field add_levels fun(lvls: LevelParams[]|LevelParams)
---@field config Triforce.Config
---@field get_config fun(): config: TriforceConfigDefaults
---@field get_levels fun(): levels: table<integer, LevelTitle>
---@field get_stats fun(): stats: Stats|nil|?
---@field has_gamification fun(silent?: boolean): gamified: boolean
---@field health Triforce.Health
---@field items Triforce.Items
---@field languages Triforce.Languages
---@field levels Triforce.Levels
---@field lualine Triforce.Lualine
---@field open_config function
---@field random_stats Triforce.RandomStats
---@field reset_all_items function
---@field reset_stats function
---@field set_config fun(key: any, value: any)
---@field stats Triforce.Stats
---@field tracker Triforce.Tracker
---@field ui Triforce.Ui
---@field util Triforce.Util
local M = {}

---@generic T: table, F
---@param t T
---@param k any
---@param fallback F
---@return F fallback
local function get(t, k, fallback)
  return Util.get(t, k, function()
    return Util.rawset(t, k, fallback)
  end, true)
end

setmetatable(M, {
  ---@param self Triforce
  ---@param k any
  __index = function(self, k)
    local raw = Util.get(self, k)
    if raw then
      return raw
    end

    if type(k) ~= 'string' then
      return
    end

    ---@cast k string
    if Util.mod_exists('triforce.' .. k) then
      return get(self, k, require('triforce.' .. k))
    end
    if k == 'add_levels' then
      return get(self, k, self.levels.add_levels)
    end
    if k == 'get_config' then
      return get(self, k, self.config.get)
    end
    if k == 'get_levels' then
      return get(self, k, self.levels.get)
    end
    if k == 'get_stats' then
      return get(self, k, self.tracker.get_stats)
    end
    if k == 'has_gamification' then
      return get(self, k, self.config.has_gamification)
    end
    if k == 'open_config' then
      return get(self, k, self.config.open_window)
    end
    if k == 'reset_all_items' then
      return get(self, k, self.items.reset_all_items)
    end
    if k == 'reset_stats' then
      return get(self, k, self.tracker.reset_stats)
    end
    if k == 'set_config' then
      return get(self, k, self.config.set)
    end
  end,
})

---@param opts TriforceConfig
---@overload fun()
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

  M.config.setup(opts or {})

  -- Create <Plug> mappings for users to map to their own keys
  vim.keymap.set(
    'n',
    '<Plug>(TriforceProfile)',
    M.show_profile,
    { desc = 'Triforce: Show profile', noremap = true, silent = true }
  )

  local config = M.get_config()

  M.levels.setup(config.override_levels)

  if M.has_gamification(true) then
    M.tracker.setup()

    M.new_achievements(config.achievements or {})

    if config.levels and #config.levels > 0 then
      M.levels.add_levels(config.levels)
    end

    vim.api.nvim_create_autocmd('ColorScheme', {
      desc = 'Sync Triforce with colorscheme changes',
      group = vim.api.nvim_create_augroup('TriforceProfile', { clear = true }),
      callback = function()
        vim.schedule(function()
          M.ui.profile.setup_highlights()
        end)
      end,
    })
  end
end

---Show profile UI
---@param tab string
---@overload fun()
function M.show_profile(tab)
  Util.validate({ tab = { tab, { 'string', 'nil' }, true } })

  if M.has_gamification() then
    if not M.get_stats() then
      M.tracker.setup()
    end

    local current_tab, dimensions = M.ui.profile.get_current_tab(), M.ui.profile.get_dimensions()
    local tab_n = tab and (M.ui.profile.get_tabs_map()[tab] or current_tab) or current_tab
    if current_tab ~= tab_n and dimensions.float and dimensions.dim_float then
      M.ui.profile.cycle_tab(nil, tab_n)
    else
      M.ui.profile.toggle(tab_n)
    end
  end
end

---Reset all stats (useful for testing)
function M.reset()
  if M.has_gamification() then
    M.reset_stats()
    M.reset_all_items()
  end
end

---Debug language tracking
function M.debug_languages()
  if M.has_gamification() then
    M.tracker.debug_languages()
  end
end

---Force save stats
function M.save_stats()
  if M.has_gamification() then
    local stats = assert(M.get_stats(), 'No stats to save')
    assert(M.stats.save(stats), 'Failed to save stats')
    vim.notify(
      ('Stats saved successfully in `%s`'):format(vim.fn.fnamemodify(stats.db_path, ':~')),
      vim.log.levels.INFO
    )
  end
end

---Show current XP progress (debug).
--- ---
function M.debug_xp()
  if M.has_gamification() then
    M.tracker.debug_xp()
  end
end

---Debug: Test achievement notification
function M.debug_achievement()
  if M.has_gamification() then
    M.tracker.debug_achievement()
  end
end

---Debug: Fix level/XP mismatch
function M.debug_fix_level()
  if M.has_gamification() then
    M.tracker.debug_fix_level()
  end
end

---@param format 'json'|'markdown'|'lua'
---@overload fun()
function M.export_stats(format)
  Util.validate({ format = { format, { 'string', 'nil' }, true } })
  format = format or 'lua'
  format = vim.list_contains({ 'json', 'lua', 'markdown' }, format) and format or 'lua'

  if M.has_gamification() then
    M.stats.export_stats(M.get_stats(), format)
  end
end

---Export stats to JSON
---
---@param file string
---@param indent string
---@overload fun(file: string)
function M.export_stats_to_json(file, indent)
  Util.validate({
    file = { file, { 'string' } },
    indent = { indent, { 'string', 'nil' }, true },
  })

  if M.has_gamification() then
    M.stats.export_to_json(M.get_stats(), file, indent or nil)
  end
end

---Export stats to Markdown
---
---@param file string
function M.export_stats_to_md(file)
  Util.validate({ file = { file, { 'string' } } })

  if M.has_gamification() then
    M.stats.export_to_md(M.get_stats(), file)
  end
end

---@param file string
function M.export_stats_to_lua(file)
  Util.validate({ file = { file, { 'string' } } })

  if M.has_gamification() then
    M.stats.export_to_lua(M.get_stats(), file)
  end
end

---@param achievements Achievement[]|Achievement
function M.new_achievements(achievements)
  Util.validate({ achievements = { achievements, { 'table' } } })

  if M.has_gamification() then
    M.achievement.new_achievements(achievements, M.get_stats())
  end
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
