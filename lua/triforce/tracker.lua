local INFO = vim.log.levels.INFO
local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local uv = vim.uv or vim.loop
local Langs = require('triforce.languages')
local Util = require('triforce.util')

---@class Triforce.Tracker
---@field augroup? integer
---@field current_stats? Stats
local M = {}

---Track line count per buffer to detect new lines
M.buffer_line_counts = {} ---@type table<integer, integer>

---Track lines typed today
M.lines_today = 0 ---@type integer

---Track current date to detect day rollover
M.current_date = os.date('%Y-%m-%d') ---@type string|osdate

---Flag to track if stats need saving
M.dirty = false ---@type boolean

---Last save timestamp to prevent rapid saves
M.last_save_time = 0 ---@type integer

---Timestamp of last keystroke (for activity-based time tracking)
M.last_activity_time = 0 ---@type integer

---Seconds of inactivity before a gap is not counted as coding time
M.idle_threshold = 300 ---@type integer

M.debug = false ---@type boolean

---@param path string
local function start_file_watch(path)
  if vim.g.triforce_watch_setup == 1 then
    return
  end

  Util.validate({ path = { path, { 'string', 'nil' }, true } })

  local event = uv.new_fs_event()
  if not event then
    return
  end

  local stats_module = require('triforce.stats')
  event:start((path and Util.is_file(path)) and path or stats_module.get_stats_path(), {}, function(err, _, events)
    if err or not events.change then
      return
    end

    M.current_stats = stats_module.load(M.debug)
  end)

  vim.g.triforce_watch_setup = 1
end

---Initialize the tracker
---@param debug? boolean
function M.setup(debug)
  Util.validate({ debug = { debug, { 'boolean', 'nil' }, true } })

  local stats_module = require('triforce.stats')

  if debug == nil then
    M.debug = false
  else
    M.debug = debug
  end

  M.current_stats = stats_module.load(M.debug)
  M.current_date = os.date('%Y-%m-%d')
  M.lines_today = 0
  stats_module.start_session(M.current_stats)
  M.augroup = vim.api.nvim_create_augroup('TriforceTracker', { clear = true })

  vim.api.nvim_create_autocmd({ 'InsertCharPre', 'TextChanged' }, {
    group = M.augroup,
    callback = function(ev)
      if Util.optget('modified', 'buf', ev.buf) then
        M.on_text_changed(ev.buf)
      end
    end,
  })
  vim.api.nvim_create_autocmd('BufWritePre', {
    group = M.augroup,
    callback = function(ev)
      if
        Util.optget('modified', 'buf', ev.buf)
        and not vim.list_contains(Langs.ignored_langs, Util.optget('filetype', 'buf', ev.buf))
      then
        M.on_save()
      end
    end,
  })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = M.augroup,
    callback = function()
      M.shutdown()
    end,
  })
  -- Auto-save timer (every 30 seconds if dirty)
  local timer = uv.new_timer()
  if not timer then
    return
  end

  start_file_watch(stats_module.db_path)

  timer:start(
    30000,
    30000,
    vim.schedule_wrap(function()
      if not (M.current_stats and M.dirty) then
        return
      end

      local now = os.time()

      -- Debounce: only save if at least 5 seconds since last save
      if now - M.last_save_time < 5 or not stats_module.save(M.current_stats) then
        return
      end

      M.dirty = false
      M.last_save_time = now
    end)
  )
end

---Check if date has rolled over and update daily activity
function M.check_date_rollover()
  local today = os.date('%Y-%m-%d')
  if today == M.current_date then
    return
  end

  -- Day changed - record yesterday's lines and reset
  if M.lines_today > 0 and M.current_stats then
    require('triforce.stats').record_daily_activity(M.current_stats, M.lines_today)
  end
  M.current_date = today
  M.lines_today = 0
end

---Track characters typed (called on text change)
---@param bufnr integer
function M.on_text_changed(bufnr)
  if not M.current_stats then
    return
  end

  local stats_module = require('triforce.stats')
  local achievement_module = require('triforce.achievement')

  -- Check for day rollover
  M.check_date_rollover()

  if vim.list_contains({ 'terminal', 'help', 'nowrite', 'nofile' }, Util.optget('buftype', 'buf', bufnr)) then
    return
  end

  -- Activity-based time tracking: only count time between actual keystrokes
  local now = os.time()
  if M.last_activity_time > 0 then
    local elapsed = now - M.last_activity_time
    if elapsed <= M.idle_threshold then
      M.current_stats.time_coding = M.current_stats.time_coding + elapsed
      M.dirty = true
    end
  end
  M.last_activity_time = now

  local current_line_count = vim.api.nvim_buf_line_count(bufnr)
  local previous_line_count = M.buffer_line_counts[bufnr] or current_line_count

  -- Track new lines if line count increased
  if current_line_count > previous_line_count then
    local new_lines = current_line_count - previous_line_count
    M.current_stats.lines_typed = M.current_stats.lines_typed + new_lines
    M.lines_today = M.lines_today + new_lines
    stats_module.add_xp(M.current_stats, Util.get_xp_rewards().line * new_lines)
  end

  -- Update the tracked line count
  M.buffer_line_counts[bufnr] = current_line_count

  -- Track character typed
  M.current_stats.chars_typed = M.current_stats.chars_typed + 1
  M.dirty = true

  -- Track character by language
  local filetype = Util.optget('filetype', 'buf', bufnr) --[[@as string]]
  if filetype ~= '' and Langs.should_track(filetype) then
    -- Initialize if needed
    if not M.current_stats.chars_by_language then
      M.current_stats.chars_by_language = {}
    end
    M.current_stats.chars_by_language[filetype] = (M.current_stats.chars_by_language[filetype] or 0) + 1
  end

  if stats_module.add_xp(M.current_stats, Util.get_xp_rewards().char) then
    M.notify_level_up()
  end

  for _, achievement in ipairs(achievement_module.check_achievements(M.current_stats)) do
    M.notify_achievement(achievement.name, achievement.desc, achievement.icon)
  end
end

---Track new lines (could be enhanced with more detailed tracking)
function M.on_new_line()
  if not M.current_stats then
    return
  end

  M.current_stats.lines_typed = M.current_stats.lines_typed + 1
  require('triforce.stats').add_xp(M.current_stats, Util.get_xp_rewards().line)
end

---Track file saves
function M.on_save()
  if not M.current_stats then
    return
  end

  local leveled_up = require('triforce.stats').add_xp(M.current_stats, Util.get_xp_rewards().save)
  M.dirty = true

  if leveled_up then
    M.notify_level_up()
  end

  -- Save immediately on file save
  local now = os.time()
  if now - M.last_save_time < 2 then -- Prevent saves more than once per 2 seconds
    return
  end

  if require('triforce.stats').save(M.current_stats) then
    M.dirty = false
    M.last_save_time = now
  end
end

---Notify user of level up
function M.notify_level_up()
  if not M.current_stats then
    return
  end

  local notifications = require('triforce.config').config.notifications
  if not (notifications and notifications.enabled and notifications.level_up) then
    return
  end

  local level = M.current_stats.level
  local xp = M.current_stats.xp
  local next_xp = require('triforce.stats').xp_for_next_level(level)

  vim.notify(
    ('󰓏 Level %d Achieved!\n\n%d XP earned • %d XP to next level'):format(level, xp, next_xp - xp),
    INFO,
    { title = ' Triforce', timeout = 3000 }
  )
end

---Notify user of achievement unlock
---@param name string
---@param desc? string
---@param icon? string
function M.notify_achievement(name, desc, icon)
  Util.validate({
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
function M.get_stats()
  return M.current_stats
end

---Shutdown tracker and save
function M.shutdown()
  if not M.current_stats then
    return
  end

  local stats_module = require('triforce.stats')

  -- Record today's lines before shutdown
  if M.lines_today > 0 then
    stats_module.record_daily_activity(M.current_stats, M.lines_today)
  end

  -- Add final active time chunk if user typed recently before closing
  if M.last_activity_time > 0 then
    local now = os.time()
    local elapsed = now - M.last_activity_time
    if elapsed <= M.idle_threshold then
      M.current_stats.time_coding = M.current_stats.time_coding + elapsed
    end
  end

  stats_module.end_session(M.current_stats)

  -- Force save on shutdown, ignore debounce
  if not stats_module.save(M.current_stats) then
    error('Failed to save stats on shutdown!', ERROR)
  end

  M.dirty = false
  M.last_save_time = os.time()
end

---Reset all stats (for testing)
function M.reset_stats()
  local stats_module = require('triforce.stats')

  M.current_stats = stats_module.default_stats()

  stats_module.save(M.current_stats)
  vim.notify('Stats reset!', INFO)
end

---Debug: Print current language stats
function M.debug_languages()
  if not M.current_stats then
    vim.notify('No stats loaded!', WARN)
    return
  end

  local langs = M.current_stats.chars_by_language or {}
  local count = 0
  local msg = 'Languages tracked:\n'

  for lang, chars in pairs(langs) do
    msg = ('%s  %s: %d chars\n'):format(msg, lang, chars)
    count = count + 1
  end

  msg = count == 0 and 'No languages tracked yet' or ('%s\nTotal: %d languages'):format(msg, count)
  vim.notify(msg, INFO)

  -- Also print to check current filetype
  vim.notify(
    ("Current filetype: '%s'"):format(Util.optget('filetype', 'buf', vim.api.nvim_get_current_buf()) or 'none'),
    INFO
  )
end

---Debug: Show current XP progress
function M.debug_xp()
  if not M.current_stats then
    vim.notify('No stats loaded!', WARN)
    return
  end

  local stats_module = require('triforce.stats')

  local next_level_xp = stats_module.xp_for_next_level(M.current_stats.level)
  local prev_level_xp = M.current_stats.level > 1 and stats_module.xp_for_next_level(M.current_stats.level - 1) or 0
  local level_xp = M.current_stats.xp - prev_level_xp
  local xp_needed = next_level_xp - prev_level_xp
  local progress = math.floor((level_xp / xp_needed) * 100)

  vim.notify(
    ('󰓏 Level %d\n\nCurrent XP: %d / %d\nProgress: %d%%\nXP to next level: %d'):format(
      M.current_stats.level,
      level_xp,
      xp_needed,
      progress,
      next_level_xp - M.current_stats.xp
    ),
    INFO,
    { title = ' Triforce Debug', timeout = 5000 }
  )
end

---Debug: Show random achievement notification (for testing)
function M.debug_achievement()
  if not M.current_stats then
    vim.notify('No stats loaded!', WARN)
    return
  end

  local achievement_mod = require('triforce.achievement')
  local achievements = achievement_mod.get_all_achievements(M.current_stats)

  -- Pick a random achievement
  local random_idx = math.random(1, #achievements)
  local achievement = achievements[random_idx]

  -- Show notification
  M.notify_achievement(achievement.name, achievement.desc, achievement.icon)

  -- Also show status in separate notification
  local status = achievement.check(M.current_stats) and '✓ Unlocked' or '✗ Locked'
  vim.notify(
    ('Test notification for: %s\n\nStatus: %s'):format(achievement.name, status),
    INFO,
    { title = ' Debug Info', timeout = 2000 }
  )
end

---Debug: Fix level/XP mismatch by recalculating level from XP
function M.debug_fix_level()
  if not M.current_stats then
    vim.notify('No stats loaded!', WARN)
    return
  end

  if not M.debug then
    return
  end

  local stats_module = require('triforce.stats')
  local current_xp = M.current_stats.xp
  local calculated_level = stats_module.calculate_level(current_xp)

  if M.current_stats.level == calculated_level then
    vim.notify(
      ('✓ No mismatch detected!\n\nLevel %d matches %d XP'):format(M.current_stats.level, current_xp),
      INFO,
      { title = ' Triforce Debug' }
    )
    return
  end

  M.current_stats.level = calculated_level
  M.dirty = true
  stats_module.save(M.current_stats)

  vim.notify(
    ('✓ Level fixed!\n\nOld: Level %d\nNew: Level %d\nXP: %d'):format(
      M.current_stats.level,
      calculated_level,
      current_xp
    ),
    WARN,
    { title = ' Triforce Debug', timeout = 5000 }
  )
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
