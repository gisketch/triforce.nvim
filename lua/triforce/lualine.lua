---Level component config
--- ---
---@class LevelShow
---Show progress bar
--- ---
---@field bar? boolean
---Show the level's icon.
--- ---
---@field icon? boolean
---Show level number
--- ---
---@field level? boolean
---Show percentage
--- ---
---@field percent? boolean
---Show the title of the level.
--- ---
---@field title? boolean
---Show XP numbers (current/needed)
--- ---
---@field xp? boolean

---@class LevelShowDefaults: LevelShow
---@field bar boolean
---@field icon boolean
---@field level boolean
---@field percent boolean
---@field title boolean
---@field xp boolean

---@class BarOptions.Chars
---@field empty? string
---@field filled? string

---@class BarOptions.CharsDefaults: BarOptions.Chars
---@field empty string
---@field filled string

---@class BarOptions
---@field chars? BarOptions.Chars
---@field length? integer

---@class BarOptionsDefaults: BarOptions
---@field chars BarOptions.CharsDefaults
---@field length integer

---Level component config
--- ---
---@class Triforce.LualineConfig.Level
---Bar options
--- ---
---@field bar? BarOptions
---Enables the level component.
--- ---
---@field enabled? boolean
---Text prefix before level number
--- ---
---@field prefix? string
---Stores which components will be shown
--- ---
---@field show? LevelShow

---Level component config.
--- ---
---@class Triforce.LualineConfig.Currency
---Enables the currency component.
--- ---
---@field enabled? boolean
---Text prefix before currency number.
--- ---
---@field prefix? string

---Achievements component config.
--- ---
---@class Triforce.LualineConfig.Achievements
---Enables the achievements component.
--- ---
---@field enabled? boolean
---Nerd Font trophy icon
--- ---
---@field icon? string
---Show unlocked/total count
--- ---
---@field show_count? boolean

---Streak component config
--- ---
---@class Triforce.LualineConfig.Streak
---@field enabled? boolean
---Nerd Font flame icon
--- ---
---@field icon? string
---Show number of days
--- ---
---@field show_days?  boolean

---Session time component config
--- ---
---@class Triforce.LualineConfig.SessionTime
---@field enabled? boolean
---Nerd Font clock icon.
--- ---
---@field icon? string
---Show time duration.
--- ---
---@field show_duration? boolean
---Can be either `'short'` (`2h 34m`) or `'long'` (`2:34:12`).
--- ---
---@field format? 'short'|'long'

---@class Triforce.LualineComponents
---@field achievements fun(opts?: Triforce.LualineConfig): component: string
---@field currency fun(opts?: Triforce.LualineConfig): component: string
---@field level fun(opts?: Triforce.LualineConfig): component: string
---@field session_time fun(opts?: Triforce.LualineConfig): component: string
---@field streak fun(opts?: Triforce.LualineConfig): component: string

---@class Triforce.LualineConfig
---Achievements component config.
--- ---
---@field achievements? Triforce.LualineConfig.Achievements
---Currency component config.
--- ---
---@field currency? Triforce.LualineConfig.Currency
---Level component config
--- ---
---@field level? Triforce.LualineConfig.Level
---Session time component config
--- ---
---@field session_time? Triforce.LualineConfig.SessionTime
---Streak component config
--- ---
---@field streak? Triforce.LualineConfig.Streak

---@class Triforce.LualineConfig.CurrencyDefaults: Triforce.LualineConfig.Currency
---@field enabled boolean
---@field prefix string

---@class Triforce.LualineConfig.LevelDefaults: Triforce.LualineConfig.Level
---@field bar BarOptionsDefaults
---@field enabled boolean
---@field prefix string
---@field show LevelShowDefaults

---@class Triforce.LualineConfig.AchievementsDefaults: Triforce.LualineConfig.Achievements
---@field icon string
---@field show_count boolean

---@class Triforce.LualineConfig.StreakDefaults: Triforce.LualineConfig.Streak
---@field icon string
---@field show_days  boolean

---@class Triforce.LualineConfig.SessionTimeDefaults: Triforce.LualineConfig.SessionTime
---@field format 'short'|'long'
---@field icon string
---@field show_duration boolean

---@class Triforce.LualineConfigDefaults: Triforce.LualineConfig
---@field achievements Triforce.LualineConfig.AchievementsDefaults
---@field currency Triforce.LualineConfig.CurrencyDefaults
---@field level Triforce.LualineConfig.LevelDefaults
---@field session_time Triforce.LualineConfig.SessionTimeDefaults
---@field streak Triforce.LualineConfig.StreakDefaults

local Util = require('triforce.util')

---Lualine integration components for Triforce
---Provides the following modular statusline components:
--- - level
--- - achievements
--- - streak
--- - session time
---@class Triforce.Lualine
---@field config Triforce.LualineConfig
local M = {}

---@return Triforce.LualineConfigDefaults defaults
function M.get_defaults()
  return { ---@type Triforce.LualineConfigDefaults
    achievements = { enabled = false, icon = '', show_count = true },
    currency = { enabled = true, prefix = '💰' },
    level = {
      enabled = true,
      bar = { length = 8, chars = { filled = '█', empty = '░' } },
      prefix = 'Lv.',
      show = { level = true, bar = true, percent = false, xp = false, title = false, icon = false },
      title = false,
    },
    session_time = { enabled = false, icon = '', show_duration = true, format = 'short' },
    streak = { enabled = false, icon = '', show_days = true },
  }
end

local cfg = M.get_defaults()

---Setup lualine integration with custom config
---@param opts? Triforce.LualineConfig User configuration
function M.setup(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  cfg = vim.tbl_deep_extend('force', cfg, opts or {})
  if not vim.list_contains({ 'short', 'long' }, cfg.session_time.format) then
    cfg.session_time.format = M.get_defaults().session_time.format
  end
end

---Get current stats safely
---@return Stats|nil|? stats
local function get_stats()
  local ok, triforce = pcall(require, 'triforce')
  if not ok then
    return
  end

  return triforce.get_stats()
end

---Generate progress bar
---@param current number Current value
---@param max number Maximum value
---@param length? integer Bar length
---@param chars? table<string, string> Characters for filled and empty
---@return string bar
local function create_progress_bar(current, max, length, chars)
  Util.validate({
    current = { current, { 'number' } },
    max = { max, { 'number' } },
    length = { length, { 'number', 'nil' }, true },
    chars = { chars, { 'table', 'nil' }, true },
  })
  length = (length and length > 0) and length or M.get_defaults().level.bar.length
  length = Util.is_int(length) and length or math.floor(length)
  chars = chars or M.get_defaults().level.bar.chars

  if max == 0 then
    return chars.empty:rep(length)
  end

  local filled = math.min(math.floor((current / max) * length), length)
  return chars.filled:rep(filled) .. chars.empty:rep(length - filled)
end

---Format time duration
---@param seconds integer Total seconds
---@param format 'short'|'long'
---@return string formatted
local function format_time(seconds, format)
  Util.validate({
    seconds = { seconds, { 'number' } },
    format = { format, { 'string' } },
  })
  format = vim.list_contains({ 'short', 'long' }, format) and format or M.get_defaults().session_time.format

  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  if seconds < 60 then
    return format == 'short' and ('%ds'):format(seconds) or ('%02d:%02d:%02d'):format(hours, minutes, seconds)
  end
  if format == 'long' then
    return ('%02d:%02d:%02d'):format(hours, minutes, seconds % 60)
  end
  if hours > 0 then
    return ('%dh %dm'):format(hours, minutes)
  end

  return ('%dm'):format(minutes)
end

---Level component - Shows level and XP progress
---@param opts? Triforce.LualineConfig.Currency Component-specific options
---@return string component
function M.currency(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  local stats = get_stats()
  local config = vim.tbl_deep_extend('force', cfg.currency, opts or {})
  if not (stats and config.enabled) then
    return ''
  end

  local parts = {} ---@type string[]
  if config.prefix then
    table.insert(parts, config.prefix)
  end

  table.insert(parts, tostring(stats.currency))
  return table.concat(parts, ' ')
end

---Level component - Shows level and XP progress
---@param opts? Triforce.LualineConfig.Level Component-specific options
---@return string component
function M.level(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  local stats = get_stats()
  local config = vim.tbl_deep_extend('force', cfg.level, opts or {})
  if not (stats and config.enabled) then
    return ''
  end

  local stats_module = require('triforce.stats')
  local xp_for_current = stats_module.xp_for_next_level(stats.level - 1)
  local xp_for_next = stats_module.xp_for_next_level(stats.level)
  local xp_needed = xp_for_next - xp_for_current
  local xp_progress = stats.xp - xp_for_current
  local parts = {} ---@type string[]

  local Levels = require('triforce.levels')

  if config.show.title then
    table.insert(parts, Levels.get_level_title(stats.level, config.show.icon))
  end

  if config.show.level then
    table.insert(parts, not config.prefix and tostring(stats.level) or (config.prefix .. stats.level))
  end

  -- Progress bar
  if config.show.bar then
    table.insert(parts, create_progress_bar(xp_progress, xp_needed, config.bar.length, config.bar.chars))
  end

  -- Percentage
  if config.show.percent then
    table.insert(parts, ('%d%%'):format(math.floor((xp_progress / xp_needed) * 100)))
  end

  -- XP numbers
  if config.show.xp then
    table.insert(parts, ('%d/%d'):format(xp_progress, xp_needed))
  end

  return table.concat(parts, ' ')
end

---Achievements component - Shows unlocked achievement count
---@param opts? Triforce.LualineConfig.Achievements Component-specific options
---@return string component
function M.achievements(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  local stats = get_stats()
  local config = vim.tbl_deep_extend('force', cfg.achievements, opts or {})
  if not (stats and config.enabled) then
    return ''
  end

  -- Count achievements
  local all_achievements = require('triforce.achievement').get_all_achievements(stats)
  local total = #all_achievements
  local unlocked = 0

  for _, _ in ipairs(stats.achievements or {}) do
    unlocked = unlocked + 1
  end

  -- Build component
  local parts = {} ---@type string[]
  if config.icon ~= '' then
    table.insert(parts, config.icon)
  end

  if config.show_count then
    table.insert(parts, ('%d/%d'):format(unlocked, total))
  end

  return table.concat(parts, ' ')
end

---Streak component - Shows current coding streak
---@param opts? Triforce.LualineConfig.Streak Component-specific options
---@return string component
function M.streak(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  local stats = get_stats()
  local config = vim.tbl_deep_extend('force', cfg.streak, opts or {})
  if not (stats and config.enabled) or stats.current_streak == 0 then
    return ''
  end

  -- Build component
  local parts = {} ---@type string[]
  if config.icon ~= '' then
    table.insert(parts, config.icon)
  end
  if config.show_days then
    table.insert(parts, tostring(stats.current_streak))
  end

  return table.concat(parts, ' ')
end

---Session time component - Shows current session duration
---@param opts? Triforce.LualineConfig.SessionTime Component-specific options
---@return string component
function M.session_time(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  local stats = get_stats()
  local config = vim.tbl_deep_extend('force', cfg.session_time, opts or {})
  if not (stats and config.enabled) or stats.last_session_start == 0 then
    return ''
  end

  local parts, duration = {}, os.time() - stats.last_session_start ---@type string[], integer
  if config.icon ~= '' then
    table.insert(parts, config.icon)
  end

  if config.show_duration then
    table.insert(parts, format_time(duration, config.format))
  end

  return table.concat(parts, ' ')
end

---Convenience function to get all components at once
---@param opts? Triforce.LualineConfig Configuration for all components
---@return Triforce.LualineComponents components Table with level, achievements, streak, session_time functions
function M.components(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  M.setup(opts)
  return {
    achievements = M.achievements,
    currency = M.currency,
    level = M.level,
    session_time = M.session_time,
    streak = M.streak,
  }
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
