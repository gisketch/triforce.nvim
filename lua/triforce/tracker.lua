local INFO = vim.log.levels.INFO
local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local util = require('triforce.util')
local uv = vim.uv or vim.loop

---@class Triforce.Tracker
---@field current_stats? Stats
---@field augroup? integer
local Tracker = {}

---Track line count per buffer to detect new lines
Tracker.buffer_line_counts = {} ---@type table<integer, integer>

---Track lines typed today
Tracker.lines_today = 0 ---@type integer

---Track current date to detect day rollover
Tracker.current_date = os.date('%Y-%m-%d') ---@type string|osdate

---Flag to track if stats need saving
Tracker.dirty = false ---@type boolean

---Last save timestamp to prevent rapid saves
Tracker.last_save_time = 0 ---@type integer

Tracker.debug = false ---@type boolean

---Initialize the tracker
---@param debug boolean
---@overload fun()
function Tracker.setup(debug)
  util.validate({ debug = { debug, { 'boolean', 'nil' }, true } })

  local stats_module = require('triforce.stats')

  Tracker.debug = debug ~= nil and debug or false
  Tracker.current_stats = stats_module.load(Tracker.debug)
  Tracker.current_date = os.date('%Y-%m-%d')
  Tracker.lines_today = 0
  stats_module.start_session(Tracker.current_stats)
  Tracker.augroup = vim.api.nvim_create_augroup('TriforceTracker', { clear = true })
  vim.api.nvim_create_autocmd({ 'TextChanged', 'InsertCharPre' }, {
    group = Tracker.augroup,
    callback = function(ev)
      Tracker.on_text_changed(ev.buf)
    end,
  })
  vim.api.nvim_create_autocmd('BufWritePre', {
    group = Tracker.augroup,
    callback = function(ev)
      local opts = { buf = ev.buf } ---@type vim.api.keyset.option
      local ft = vim.api.nvim_get_option_value('filetype', opts)
      local modified = vim.api.nvim_get_option_value('modified', opts)
      if modified and not vim.list_contains(require('triforce.languages').ignored_langs, ft) then
        Tracker.on_save()
      end
    end,
  })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = Tracker.augroup,
    callback = function()
      Tracker.shutdown()
    end,
  })
  -- Auto-save timer (every 30 seconds if dirty)
  local timer = uv.new_timer()
  if not timer then
    return
  end

  timer:start(
    30000,
    30000,
    vim.schedule_wrap(function()
      if not (Tracker.current_stats and Tracker.dirty) then
        return
      end

      local now = os.time()

      -- Debounce: only save if at least 5 seconds since last save
      if now - Tracker.last_save_time < 5 or not stats_module.save(Tracker.current_stats) then
        return
      end

      Tracker.dirty = false
      Tracker.last_save_time = now
    end)
  )
end

---Check if date has rolled over and update daily activity
function Tracker.check_date_rollover()
  local today = os.date('%Y-%m-%d')
  if today == Tracker.current_date then
    return
  end

  -- Day changed - record yesterday's lines and reset
  if Tracker.lines_today > 0 and Tracker.current_stats then
    require('triforce.stats').record_daily_activity(Tracker.current_stats, Tracker.lines_today)
  end
  Tracker.current_date = today
  Tracker.lines_today = 0
end

---Track characters typed (called on text change)
---@param bufnr integer
function Tracker.on_text_changed(bufnr)
  if not Tracker.current_stats then
    return
  end

  local stats_module = require('triforce.stats')
  local achievement_module = require('triforce.achievement')

  -- Check for day rollover
  Tracker.check_date_rollover()

  local buftype = vim.api.nvim_get_option_value('buftype', { buf = bufnr })
  if vim.list_contains({ 'terminal', 'help', 'nowrite', 'nofile' }, buftype) then
    return
  end

  local current_line_count = vim.api.nvim_buf_line_count(bufnr)
  local previous_line_count = Tracker.buffer_line_counts[bufnr] or current_line_count

  -- Track new lines if line count increased
  if current_line_count > previous_line_count then
    local new_lines = current_line_count - previous_line_count
    Tracker.current_stats.lines_typed = Tracker.current_stats.lines_typed + new_lines
    Tracker.lines_today = Tracker.lines_today + new_lines
    stats_module.add_xp(Tracker.current_stats, util.get_xp_rewards().line * new_lines)
  end

  -- Update the tracked line count
  Tracker.buffer_line_counts[bufnr] = current_line_count

  -- Track character typed
  Tracker.current_stats.chars_typed = Tracker.current_stats.chars_typed + 1
  Tracker.dirty = true

  -- Track character by language
  local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr }) ---@type string
  if filetype ~= '' and require('triforce.languages').should_track(filetype) then
    -- Initialize if needed
    if not Tracker.current_stats.chars_by_language then
      Tracker.current_stats.chars_by_language = {}
    end

    Tracker.current_stats.chars_by_language[filetype] = (Tracker.current_stats.chars_by_language[filetype] or 0) + 1
  end

  if stats_module.add_xp(Tracker.current_stats, util.get_xp_rewards().char) then
    Tracker.notify_level_up()
  end

  for _, achievement in ipairs(achievement_module.check_achievements(Tracker.current_stats)) do
    Tracker.notify_achievement(achievement.name, achievement.desc, achievement.icon)
  end
end

---Track new lines (could be enhanced with more detailed tracking)
function Tracker.on_new_line()
  if not Tracker.current_stats then
    return
  end

  Tracker.current_stats.lines_typed = Tracker.current_stats.lines_typed + 1
  require('triforce.stats').add_xp(Tracker.current_stats, util.get_xp_rewards().line)
end

---Track file saves
function Tracker.on_save()
  if not Tracker.current_stats then
    return
  end

  local leveled_up = require('triforce.stats').add_xp(Tracker.current_stats, util.get_xp_rewards().save)
  Tracker.dirty = true

  if leveled_up then
    Tracker.notify_level_up()
  end

  -- Save immediately on file save
  local now = os.time()
  if now - Tracker.last_save_time < 2 then -- Prevent saves more than once per 2 seconds
    return
  end

  if require('triforce.stats').save(Tracker.current_stats) then
    Tracker.dirty = false
    Tracker.last_save_time = now
  end
end

---Notify user of level up
function Tracker.notify_level_up()
  if not Tracker.current_stats then
    return
  end

  local notifications = require('triforce.config').config.notifications
  if not (notifications and notifications.enabled and notifications.level_up) then
    return
  end

  local level = Tracker.current_stats.level
  local xp = Tracker.current_stats.xp
  local next_xp = require('triforce.stats').xp_for_next_level(level)

  vim.notify(
    ('󰓏 Level %d Achieved!\n\n%d XP earned • %d XP to next level'):format(level, xp, next_xp - xp),
    INFO,
    { title = ' Triforce', timeout = 3000 }
  )
end

---Notify user of achievement unlock
---@param name string
---@param desc string
---@param icon string
---@overload fun(name: string)
---@overload fun(name: string, desc: string)
function Tracker.notify_achievement(name, desc, icon)
  util.validate({
    name = { name, { 'string' } },
    desc = { desc, { 'string', 'nil' }, true },
    icon = { icon, { 'string', 'nil' }, true },
  })

  local notifications = require('triforce.config').config.notifications
  if not notifications or not (notifications.enabled and notifications.achievements) then
    return
  end

  local message = (icon or '🏆') .. ' ' .. name
  if desc then
    message = message .. '\n\n' .. desc
  end

  vim.notify(message, INFO, { title = ' Achievement Unlocked', timeout = 3500 })
end

---Get current stats
---@return Stats|nil stats
function Tracker.get_stats()
  return Tracker.current_stats
end

---Shutdown tracker and save
function Tracker.shutdown()
  if not Tracker.current_stats then
    return
  end

  local stats_module = require('triforce.stats')

  -- Record today's lines before shutdown
  if Tracker.lines_today > 0 then
    stats_module.record_daily_activity(Tracker.current_stats, Tracker.lines_today)
  end

  stats_module.end_session(Tracker.current_stats)

  -- Force save on shutdown, ignore debounce
  if not stats_module.save(Tracker.current_stats) then
    error('Failed to save stats on shutdown!', ERROR)
  end

  Tracker.dirty = false
  Tracker.last_save_time = os.time()
end

---Reset all stats (for testing)
function Tracker.reset_stats()
  local stats_module = require('triforce.stats')

  Tracker.current_stats = stats_module.default_stats()

  stats_module.save(Tracker.current_stats)
  vim.notify('Stats reset!', INFO)
end

---Debug: Print current language stats
function Tracker.debug_languages()
  if not Tracker.current_stats then
    vim.notify('No stats loaded!', WARN)
    return
  end

  local langs = Tracker.current_stats.chars_by_language or {}
  local count = 0
  local msg = 'Languages tracked:\n'

  for lang, chars in pairs(langs) do
    msg = ('%s  %s: %d chars\n'):format(msg, lang, chars)
    count = count + 1
  end

  msg = count == 0 and 'No languages tracked yet' or ('%s\nTotal: %d languages'):format(msg, count)
  vim.notify(msg, INFO)

  -- Also print to check current filetype
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  vim.notify(("Current filetype: '%s'"):format(ft or 'none'), INFO)
end

---Debug: Show current XP progress
function Tracker.debug_xp()
  if not Tracker.current_stats then
    vim.notify('No stats loaded!', WARN)
    return
  end

  local stats_module = require('triforce.stats')

  local next_level_xp = stats_module.xp_for_next_level(Tracker.current_stats.level)
  local prev_level_xp = Tracker.current_stats.level > 1
      and stats_module.xp_for_next_level(Tracker.current_stats.level - 1)
    or 0
  local level_xp = Tracker.current_stats.xp - prev_level_xp
  local xp_needed = next_level_xp - prev_level_xp
  local progress = math.floor((level_xp / xp_needed) * 100)

  vim.notify(
    ('󰓏 Level %d\n\nCurrent XP: %d / %d\nProgress: %d%%\nXP to next level: %d'):format(
      Tracker.current_stats.level,
      level_xp,
      xp_needed,
      progress,
      next_level_xp - Tracker.current_stats.xp
    ),
    INFO,
    { title = ' Triforce Debug', timeout = 5000 }
  )
end

---Debug: Show random achievement notification (for testing)
function Tracker.debug_achievement()
  if not Tracker.current_stats then
    vim.notify('No stats loaded!', WARN)
    return
  end

  local achievement_mod = require('triforce.achievement')
  local achievements = achievement_mod.get_all_achievements(Tracker.current_stats)

  -- Pick a random achievement
  local random_idx = math.random(1, #achievements)
  local achievement = achievements[random_idx]

  -- Show notification
  Tracker.notify_achievement(achievement.name, achievement.desc, achievement.icon)

  -- Also show status in separate notification
  local status = achievement.check(Tracker.current_stats) and '✓ Unlocked' or '✗ Locked'
  vim.notify(
    ('Test notification for: %s\n\nStatus: %s'):format(achievement.name, status),
    INFO,
    { title = ' Debug Info', timeout = 2000 }
  )
end

---Debug: Fix level/XP mismatch by recalculating level from XP
function Tracker.debug_fix_level()
  if not Tracker.current_stats then
    vim.notify('No stats loaded!', WARN)
    return
  end

  if not Tracker.debug then
    return
  end

  local stats_module = require('triforce.stats')
  local current_xp = Tracker.current_stats.xp
  local calculated_level = stats_module.calculate_level(current_xp)

  if Tracker.current_stats.level == calculated_level then
    vim.notify(
      ('✓ No mismatch detected!\n\nLevel %d matches %d XP'):format(Tracker.current_stats.level, current_xp),
      INFO,
      { title = ' Triforce Debug' }
    )
    return
  end

  Tracker.current_stats.level = calculated_level
  Tracker.dirty = true
  stats_module.save(Tracker.current_stats)

  vim.notify(
    ('✓ Level fixed!\n\nOld: Level %d\nNew: Level %d\nXP: %d'):format(
      Tracker.current_stats.level,
      calculated_level,
      current_xp
    ),
    WARN,
    { title = ' Triforce Debug', timeout = 5000 }
  )
end

return Tracker
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
