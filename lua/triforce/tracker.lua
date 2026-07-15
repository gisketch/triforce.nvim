local INFO = vim.log.levels.INFO
local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local uv = vim.uv or vim.loop
local Util = require('triforce.util')

local current_stats ---@type Stats
local event ---@type nil|uv.uv_fs_event_t
local augroup ---@type integer

---@generic T
---@param old T
---@param new T
---@return T merged
local function merge_stats(old, new)
  Util.validate({
    old = { old, { 'table' } },
    new = { new, { 'table' } },
  })
  local stats = {}
  for k, v in pairs(new) do
    if old[k] == nil or type(v) == 'boolean' then
      stats[k] = v
    elseif type(v) == 'number' then
      stats[k] = v > old[k] and v or old[k]
    elseif type(v) == 'table' then
      stats[k] = merge_stats(old[k], v)
    elseif type(v) == 'string' then
      stats[k] = old[k]
    end
  end
  return stats
end

---Track line count per buffer to detect new lines.
--- ---
local buffer_line_counts = {} ---@type table<integer, integer>

---Track lines typed today.
--- ---
local lines_today = 0 ---@type integer

---Track current date to detect day rollover.
--- ---
local current_date = os.date('%Y-%m-%d') ---@type string|osdate

---Flag to track if stats need saving.
--- ---
local dirty = false ---@type boolean

---Last save timestamp to prevent rapid saves.
--- ---
local last_save_time = 0 ---@type integer

---Timestamp of last keystroke (for activity-based time tracking).
--- ---
local last_activity_time = 0 ---@type integer

---Seconds of inactivity before a gap is not counted as coding time.
--- ---
local idle_threshold = 300 ---@type integer

---Debug mode is enabled.
--- ---
local debug_enabled = false ---@type boolean

---@class Triforce.Tracker
local M = {}

---@param stats Stats
function M.update_stats(stats)
  Util.validate({ stats = { stats, { 'table' } } })

  current_stats = vim.deepcopy(stats)
end

---@param path string
local function start_file_watch(path)
  Util.validate({ path = { path, { 'string', 'nil' }, true } })
  if vim.g.triforce_watch_setup == 1 then
    return
  end

  event = uv.new_fs_event()
  if not event then
    return
  end

  event:start(
    (path and Util.is_file(path)) and path or require('triforce.stats').get_stats_path(),
    {},
    vim.schedule_wrap(function(err, _, events)
      if not err and events.change then
        local stats = require('triforce.stats').load(debug_enabled)
        if stats.last_session_start == 0 then
          require('triforce.stats').save(merge_stats(current_stats, stats))
        end
      end
    end)
  )

  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = augroup,
    once = true,
    callback = function()
      if event and event:is_active() then
        event:close()
        event = nil
      end
    end,
  })

  vim.g.triforce_watch_setup = 1
end

---Initialize the tracker
---@param debug? boolean
function M.setup(debug)
  Util.validate({ debug = { debug, { 'boolean', 'nil' }, true } })
  if debug == nil then
    debug = false
  end

  debug_enabled = debug

  local stats_module = require('triforce.stats')

  current_stats = stats_module.load(debug_enabled)
  current_date = os.date('%Y-%m-%d')
  lines_today = 0
  stats_module.start_session(current_stats)
  augroup = vim.api.nvim_create_augroup('TriforceTracker', { clear = true })

  local events = { 'TextChanged', 'TextChangedI' } ---@type vim.api.keyset.events[]
  if vim.fn.has('nvim-0.13') == 1 then
    table.insert(events, 'TextPutPost')
  end
  vim.api.nvim_create_autocmd(events, {
    group = augroup,
    callback = function(ev)
      if Util.optget('modified', 'buf', ev.buf) then
        M.on_text_changed(ev.buf)
      end
    end,
  })
  vim.api.nvim_create_autocmd('BufWritePre', {
    group = augroup,
    callback = function(ev)
      if
        Util.optget('modified', 'buf', ev.buf)
        and not vim.list_contains(
          require('triforce.languages').get_ignored_langs(),
          Util.optget('filetype', 'buf', ev.buf)
        )
      then
        M.on_save()
      end
    end,
  })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = augroup,
    callback = M.shutdown,
  })
  -- Auto-save timer (every 30 seconds if dirty)
  local timer = uv.new_timer()
  if not timer then
    return
  end

  start_file_watch(stats_module.get_db_path())

  timer:start(
    10000,
    10000,
    vim.schedule_wrap(function()
      if not (current_stats and dirty) then
        return
      end

      local now = os.time()

      -- Debounce: only save if at least 5 seconds since last save
      if now - last_save_time < 5 or not stats_module.save(current_stats) then
        return
      end

      dirty = false
      last_save_time = now
    end)
  )

  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = augroup,
    once = true,
    callback = function()
      if timer and timer:is_active() then
        timer:stop()
        timer = nil
      end
    end,
  })
end

---Check if date has rolled over and update daily activity
function M.check_date_rollover()
  local today = os.date('%Y-%m-%d')
  if today == current_date then
    return
  end

  -- Day changed - record yesterday's lines and reset
  if lines_today > 0 and current_stats then
    require('triforce.stats').record_daily_activity(current_stats, lines_today)
  end
  current_date = today
  lines_today = 0
end

---Track characters typed (called on text change)
---@param bufnr integer
function M.on_text_changed(bufnr)
  if not current_stats then
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
  if last_activity_time > 0 then
    local elapsed = now - last_activity_time
    if elapsed <= idle_threshold then
      current_stats.time_coding = current_stats.time_coding + elapsed
      dirty = true
    end
  end
  last_activity_time = now

  local current_line_count = vim.api.nvim_buf_line_count(bufnr)
  local previous_line_count = buffer_line_counts[bufnr] or current_line_count

  -- Track new lines if line count increased
  if current_line_count > previous_line_count then
    local new_lines = current_line_count - previous_line_count
    current_stats.lines_typed = current_stats.lines_typed + new_lines
    current_stats.currency = stats_module.add_currency(current_stats, 1)
    lines_today = lines_today + new_lines
    stats_module.add_xp(current_stats, Util.get_xp_rewards().line * new_lines, true)
  end

  -- Update the tracked line count
  buffer_line_counts[bufnr] = current_line_count

  -- Track character typed
  current_stats.chars_typed = current_stats.chars_typed + 1
  dirty = true

  -- Track character by language
  local filetype = Util.optget('filetype', 'buf', bufnr) --[[@as string]]
  if filetype ~= '' and require('triforce.languages').should_track(filetype) then
    -- Initialize if needed
    if not current_stats.chars_by_language then
      current_stats.chars_by_language = {}
    end
    current_stats.chars_by_language[filetype] = (current_stats.chars_by_language[filetype] or 0) + 1
  end

  if stats_module.add_xp(current_stats, Util.get_xp_rewards().char) then
    M.notify_level_up()
  end

  for _, achievement in ipairs(achievement_module.check_achievements(current_stats)) do
    M.notify_achievement(achievement.name, achievement.desc, achievement.icon)
  end
end

---Track new lines (could be enhanced with more detailed tracking)
function M.on_new_line()
  if not current_stats then
    return
  end

  current_stats.lines_typed = current_stats.lines_typed + 1
  require('triforce.stats').add_xp(current_stats, Util.get_xp_rewards().line)
end

---Track file saves
function M.on_save()
  if not current_stats then
    return
  end

  local leveled_up = require('triforce.stats').add_xp(current_stats, Util.get_xp_rewards().save)
  dirty = true

  if leveled_up then
    M.notify_level_up()
  end

  -- Save immediately on file save
  local now = os.time()
  if now - last_save_time < 2 then -- Prevent saves more than once per 2 seconds
    return
  end

  if require('triforce.stats').save(current_stats) then
    dirty = false
    last_save_time = now
  end
end

---Notify user of level up
function M.notify_level_up()
  if not current_stats then
    return
  end

  local notifications = require('triforce.config').get().notifications
  if not (notifications and notifications.enabled and notifications.level_up) then
    return
  end

  local level = current_stats.level
  local xp = current_stats.xp
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

  local notifications = require('triforce.config').get().notifications
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
  return current_stats
end

---Shutdown tracker and save
function M.shutdown()
  if not current_stats then
    return
  end

  local stats_module = require('triforce.stats')

  -- Record today's lines before shutdown
  if lines_today > 0 then
    current_stats = stats_module.record_daily_activity(current_stats, lines_today)
  end

  -- Add final active time chunk if user typed recently before closing
  if last_activity_time > 0 then
    local now = os.time()
    local elapsed = now - last_activity_time
    if elapsed <= idle_threshold then
      current_stats.time_coding = current_stats.time_coding + elapsed
    end
  end

  current_stats = stats_module.end_session(current_stats)

  -- Force save on shutdown, ignore debounce
  if not stats_module.save(current_stats) then
    error('Failed to save stats on shutdown!', ERROR)
  end

  dirty = false
  last_save_time = os.time()
end

---Reset all stats (for testing)
function M.reset_stats()
  local stats_module = require('triforce.stats')

  current_stats = stats_module.default_stats()
  if stats_module.save(current_stats) then
    vim.notify('Stats reset!', INFO)
  end
end

---Debug: Print current language stats
function M.debug_languages()
  if not current_stats then
    vim.notify('No stats loaded!', WARN)
    return
  end

  local langs = current_stats.chars_by_language or {}
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
  if not current_stats then
    vim.notify('No stats loaded!', WARN)
    return
  end

  local stats_module = require('triforce.stats')

  local next_level_xp = stats_module.xp_for_next_level(current_stats.level)
  local prev_level_xp = current_stats.level > 1 and stats_module.xp_for_next_level(current_stats.level - 1) or 0
  local level_xp = current_stats.xp - prev_level_xp
  local xp_needed = next_level_xp - prev_level_xp
  local progress = math.floor((level_xp / xp_needed) * 100)

  vim.notify(
    ('󰓏 Level %d\n\nCurrent XP: %d / %d\nProgress: %d%%\nXP to next level: %d'):format(
      current_stats.level,
      level_xp,
      xp_needed,
      progress,
      next_level_xp - current_stats.xp
    ),
    INFO,
    { title = ' Triforce Debug', timeout = 5000 }
  )
end

---Debug: Show random achievement notification (for testing)
function M.debug_achievement()
  if not current_stats then
    vim.notify('No stats loaded!', WARN)
    return
  end

  local achievement_mod = require('triforce.achievement')
  local achievements = achievement_mod.get_all_achievements(current_stats)

  -- Pick a random achievement
  local achievement = achievements[math.random(1, #achievements)]

  -- Show notification
  M.notify_achievement(achievement.name, achievement.desc, achievement.icon)

  -- Also show status in separate notification
  local status = achievement.check(current_stats) and '✓ Unlocked' or '✗ Locked'
  vim.notify(
    ('Test notification for: %s\n\nStatus: %s'):format(achievement.name, status),
    INFO,
    { title = ' Debug Info', timeout = 2000 }
  )
end

---Debug: Fix level/XP mismatch by recalculating level from XP
function M.debug_fix_level()
  if not current_stats then
    vim.notify('No stats loaded!', WARN)
    return
  end

  if not debug_enabled then
    return
  end

  local stats_module = require('triforce.stats')
  local current_xp = current_stats.xp
  local calculated_level = stats_module.calculate_level(current_xp)

  if current_stats.level == calculated_level then
    vim.notify(
      ('✓ No mismatch detected!\n\nLevel %d matches %d XP'):format(current_stats.level, current_xp),
      INFO,
      { title = ' Triforce Debug' }
    )
    return
  end

  current_stats.level = calculated_level
  dirty = true
  stats_module.save(current_stats)

  vim.notify(
    ('✓ Level fixed!\n\nOld: Level %d\nNew: Level %d\nXP: %d'):format(
      current_stats.level,
      calculated_level,
      current_xp
    ),
    WARN,
    { title = ' Triforce Debug', timeout = 5000 }
  )
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
