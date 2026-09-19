local INFO = vim.log.levels.INFO
local WARN = vim.log.levels.WARN
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

  event = vim.uv.new_fs_event()
  if event then
    event:start(
      (path and Util.is_file(path)) and path or require('triforce.stats').get_stats_path(),
      {},
      vim.schedule_wrap(function(err, _, ev)
        if not err and ev.change then
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
end

---Initialize the tracker
---@param debug? boolean
function M.setup(debug)
  Util.validate({ debug = { debug, { 'boolean', 'nil' }, true } })
  if debug == nil then
    debug = false
  end

  debug_enabled = debug
  current_stats, current_date, lines_today = require('triforce.stats').load(debug_enabled), os.date('%Y-%m-%d'), 0
  require('triforce.stats').start_session(current_stats)
  augroup = vim.api.nvim_create_augroup('TriforceTracker', { clear = true })

  vim.api.nvim_create_autocmd(
    { 'TextChanged', 'TextChangedI', vim.fn.has('nvim-0.13') == 1 and 'TextPutPost' or nil },
    {
      group = augroup,
      callback = function(ev)
        if Util.optget('modified', 'buf', ev.buf) then
          M.on_text_changed(ev.buf)
        end
      end,
    }
  )
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
  vim.api.nvim_create_autocmd('VimLeavePre', { callback = M.shutdown, group = augroup })
  -- Auto-save timer (every 30 seconds if dirty)
  local timer = vim.uv.new_timer()
  if not timer then
    return
  end

  start_file_watch(require('triforce.stats').get_db_path())

  timer:start(
    10000,
    10000,
    vim.schedule_wrap(function()
      if current_stats and dirty then
        local now = os.time()
        if now - last_save_time >= 5 and require('triforce.stats').save(current_stats) then
          dirty, last_save_time = false, now
        end
      end
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
  -- Day changed - record yesterday's lines and reset
  if today ~= current_date then
    if lines_today > 0 and current_stats then
      require('triforce.stats').record_daily_activity(current_stats, lines_today)
    end
    current_date, lines_today = today, 0
  end
end

---Track characters typed (called on text change)
---@param bufnr integer
function M.on_text_changed(bufnr)
  if current_stats then
    M.check_date_rollover()

    if vim.list_contains({ 'terminal', 'help', 'nowrite', 'nofile' }, Util.optget('buftype', 'buf', bufnr)) then
      return
    end

    -- Activity-based time tracking: only count time between actual keystrokes
    local now = os.time()
    if last_activity_time > 0 and now - last_activity_time <= idle_threshold then
      current_stats.time_coding, dirty = Util.add(current_stats.time_coding, now, -last_activity_time), true
    end
    last_activity_time = now

    local current_line_count = vim.api.nvim_buf_line_count(bufnr)
    local previous_line_count = buffer_line_counts[bufnr] or current_line_count
    local stats_module = require('triforce.stats')
    if current_line_count > previous_line_count then -- Track new lines if line count increased
      current_stats.lines_typed = current_stats.lines_typed + current_line_count - previous_line_count
      current_stats.currency = stats_module.add_currency(current_stats, 1)
      lines_today = Util.add(lines_today, current_line_count, -previous_line_count)
      local _, new_stats = stats_module.add_xp(
        current_stats,
        Util.get_xp_rewards().line * (current_line_count - previous_line_count),
        true
      )

      M.update_stats(new_stats)
    end

    buffer_line_counts[bufnr], current_stats.chars_typed, dirty =
      current_line_count, Util.add(current_stats.chars_typed, 1), true

    local filetype = Util.optget('filetype', 'buf', bufnr) --[[@as string]]
    if filetype ~= '' and require('triforce.languages').should_track(filetype) then -- Track character by language
      current_stats.chars_by_language = current_stats.chars_by_language or {}
      current_stats.chars_by_language[filetype] = (current_stats.chars_by_language[filetype] or 0) + 1
    end

    local leveled_up, new_stats = stats_module.add_xp(current_stats, Util.get_xp_rewards().char)
    M.update_stats(new_stats)

    if leveled_up then
      M.notify_level_up()
    end

    for _, achievement in ipairs(require('triforce.achievement').check_achievements(current_stats)) do
      M.notify_achievement(achievement.name, achievement.desc, achievement.icon)
    end
  end
end

---Track new lines (could be enhanced with more detailed tracking)
function M.on_new_line()
  if current_stats then
    current_stats.lines_typed = current_stats.lines_typed + 1

    local _, new_stats = require('triforce.stats').add_xp(current_stats, Util.get_xp_rewards().line)
    M.update_stats(new_stats)
  end
end

---Track file saves
function M.on_save()
  if current_stats then
    local leveled_up, new_stats = require('triforce.stats').add_xp(current_stats, Util.get_xp_rewards().save)
    M.update_stats(new_stats)
    dirty = true

    if leveled_up then
      M.notify_level_up()
    end

    -- Save immediately on file save
    local now = os.time()
    if now - last_save_time >= 2 and require('triforce.stats').save(current_stats) then -- Prevent saves more than once per 2 seconds
      dirty, last_save_time = false, now
    end
  end
end

---Notify user of level up
function M.notify_level_up()
  local notifications = require('triforce.config').get().notifications
  if current_stats and notifications.enabled and notifications.level_up then
    vim.notify(
      ('triforce.nvim:\n\n  New Level: %d\n  %d XP earned\n  %d XP to next level'):format(
        current_stats.level,
        current_stats.xp,
        require('triforce.stats').xp_for_next_level(current_stats.level) - current_stats.xp
      ),
      INFO
    )
  end
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
  if notifications and notifications.enabled and notifications.achievements then
    vim.notify(
      ((icon or '🏆') .. ' ' .. name) .. (desc and ('\n\n' .. desc) or ''),
      INFO,
      { title = ' Achievement Unlocked', timeout = 3500 }
    )
  end
end

---Get current stats
---@return Stats|nil|? stats
function M.get_stats()
  return current_stats
end

---Shutdown tracker and save
function M.shutdown()
  if current_stats then
    local stats_module = require('triforce.stats')
    if lines_today > 0 then -- Record today's lines before shutdown
      current_stats = stats_module.record_daily_activity(current_stats, lines_today)
    end

    local now = os.time()
    if last_activity_time > 0 and now - last_activity_time <= idle_threshold then -- Add final active time chunk if user typed recently before closing
      current_stats.time_coding = current_stats.time_coding + now - last_activity_time
    end

    current_stats = stats_module.end_session(current_stats)
    if not stats_module.save(current_stats) then -- Force save on shutdown, ignore debounce
      vim.notify('triforce.nvim - Failed to save stats on shutdown!', vim.log.levels.ERROR)
    else
      dirty, last_save_time = false, os.time()
    end
  end
end

---Reset all stats (for testing)
function M.reset_stats()
  current_stats = require('triforce.stats').default_stats()
  if require('triforce.stats').save(current_stats) then
    vim.notify('triforce.nvim - Stats reset!', INFO)
  end
end

---Debug: Print current language stats
function M.debug_languages()
  if current_stats then
    local langs, count, msg = current_stats.chars_by_language or {}, 0, 'triforce.nvim:\n\nLanguages tracked:\n'
    table.sort(langs, function(a, b)
      return a > b
    end)
    for lang, chars in pairs(langs) do
      msg, count = ('%s  %s: %d chars\n'):format(msg, lang, chars), Util.add(count, 1)
    end

    vim.notify(
      count == 0 and 'triforce.nvim - No languages tracked yet' or ('%s\nTotal: %d languages'):format(msg, count),
      INFO
    )
    vim.notify( -- Also print to check current filetype
      ("triforce.nvim - Current filetype: '%s'"):format(
        Util.optget('filetype', 'buf', vim.api.nvim_get_current_buf()) or 'none'
      ),
      INFO
    )
  else
    vim.notify('triforce.nvim - No stats loaded!', WARN)
  end
end

---Debug: Show current XP progress
function M.debug_xp()
  if current_stats then
    local stats_module = require('triforce.stats')
    local next_level_xp = stats_module.xp_for_next_level(current_stats.level)
    local prev_level_xp = current_stats.level > 1 and stats_module.xp_for_next_level(current_stats.level - 1) or 0
    vim.notify(
      ('triforce.nvim:\n- Level: %d\n- Current XP: %d/%d\n- Progress: %d%%\n- XP needed for level up: %d'):format(
        current_stats.level,
        current_stats.xp - prev_level_xp,
        next_level_xp - prev_level_xp,
        math.floor(((current_stats.xp - prev_level_xp) / (next_level_xp - prev_level_xp)) * 100),
        next_level_xp - current_stats.xp
      ),
      INFO
    )
  else
    vim.notify('triforce.nvim - No stats loaded!', WARN)
  end
end

---Debug: Show random achievement notification (for testing)
function M.debug_achievement()
  if current_stats then
    local achievements = require('triforce.achievement').get_all_achievements(current_stats)
    local achievement = achievements[math.random(1, #achievements)] -- Pick a random achievement
    M.notify_achievement(achievement.name, achievement.desc, achievement.icon)
    vim.notify(
      ('triforce.nvim - Test notification for: %s\nStatus: %s'):format(
        achievement.name,
        achievement.check(current_stats) and '✓ Unlocked' or '✗ Locked'
      ),
      INFO
    )
  else
    vim.notify('triforce.nvim - No stats loaded!', WARN)
  end
end

---Debug: Fix level/XP mismatch by recalculating level from XP
function M.debug_fix_level()
  if not current_stats then
    vim.notify('No stats loaded!', WARN)
  elseif debug_enabled then
    local calculated_level = require('triforce.stats').calculate_level(current_stats.xp)
    if current_stats.level == calculated_level then
      vim.notify(('triforce.nvim - ✓ Level %d matches %d XP'):format(current_stats.level, current_stats.xp), INFO)
    else
      current_stats.level, dirty = calculated_level, true
      require('triforce.stats').save(current_stats)

      vim.notify(
        ('triforce.nvim - ✓ Old Level: %d\nNew Level: %d\nXP: %d'):format(
          current_stats.level,
          calculated_level,
          current_stats.xp
        ),
        WARN
      )
    end
  end
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
