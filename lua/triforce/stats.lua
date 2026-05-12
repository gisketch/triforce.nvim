---Stats tracking and persistence module
---@class Stats
---Unlocked achievements.
--- ---
---@field achievements table<string, boolean>
---Characters typed per language.
--- ---
---@field chars_by_language table<string, integer>
---Total characters typed.
--- ---
---@field chars_typed integer
---Current consecutive day streak.
--- ---
---@field current_streak integer
---Lines typed per day (`YYYY-MM-DD` format).
--- ---
---@field daily_activity table<string, integer>
---@field db_path string
---Timestamp of session start.
--- ---
---@field last_session_start integer
---Current level.
--- ---
---@field level integer
---Total lines typed.
--- ---
---@field lines_typed integer
---Longest ever streak.
--- ---
---@field longest_streak integer
---Total sessions.
--- ---
---@field sessions integer
---Total time in seconds.
--- ---
---@field time_coding integer
---Total experience points
--- ---
---@field xp number

local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local uv = vim.uv or vim.loop
local Util = require('triforce.util')
local Languages = require('triforce.languages')

---@class Triforce.Stats
---@field calibrated? true
---@field db_path? string
---Configurable level progression.
--- ---
---@field level_config LevelProgression
local M = {}

M.level_config = {
  tier_1 = { min_level = 1, max_level = 10, xp_per_level = 500 },
  tier_2 = { min_level = 11, max_level = 20, xp_per_level = 750 },
  tier_3 = { min_level = 21, max_level = 30, xp_per_level = 1250 },
  tier_4 = { min_level = 31, max_level = 40, xp_per_level = 2500 },
  tier_5 = { min_level = 41, max_level = 50, xp_per_level = 3750 },
  tier_6 = { min_level = 51, max_level = 75, xp_per_level = 5000 },
  tier_7 = { min_level = 76, max_level = 100, xp_per_level = 10000 },
  tier_8 = { min_level = 101, max_level = 150, xp_per_level = 12500 },
  tier_9 = { min_level = 151, max_level = 225, xp_per_level = 15000 },
  tier_10 = { min_level = 226, max_level = math.huge, xp_per_level = 25000 },
}

---@return Stats stats
function M.default_stats()
  local stats = { ---@type Stats
    achievements = {},
    chars_by_language = {},
    chars_typed = 0,
    current_streak = 0,
    daily_activity = {},
    db_path = vim.fs.joinpath(vim.fn.stdpath('data'), 'triforce_stats.json'),
    last_session_start = 0,
    level = 1,
    lines_typed = 0,
    longest_streak = 0,
    sessions = 0,
    time_coding = 0,
    xp = 0,
  }

  return stats
end

---Get the stats file path
---@return string db_path
function M.get_stats_path()
  return M.db_path or M.default_stats().db_path
end

---@param stats Stats
---@return boolean valid
function M.validate_stats(stats)
  Util.validate({ stats = { stats, { 'table' } } })
  if vim.tbl_isempty(stats) or vim.islist(stats) then
    return false
  end

  local keys = vim.tbl_keys(stats) --[[@as string[]\]]
  for _, key in ipairs(vim.tbl_keys(M.default_stats())) do
    if not vim.list_contains(keys, key) then
      return false
    end
  end
  return true
end

---Load stats from disk
---@param debug? boolean
---@return Stats merged
function M.load(debug)
  Util.validate({ debug = { debug, { 'boolean', 'nil' }, true } })
  if debug == nil then
    debug = false
  end

  local path = M.get_stats_path()
  if vim.fn.filereadable(path) == 0 then
    return M.default_stats()
  end

  local stat = uv.fs_stat(path)
  local fd = uv.fs_open(path, 'r', tonumber('644', 8))
  if not (stat and fd) then
    return M.default_stats()
  end

  local data = uv.fs_read(fd, stat.size)
  uv.fs_close(fd)
  if not data or data == '' then
    return M.default_stats()
  end

  local lines = vim.split(data, '\n', { trimempty = false })
  local ok, stats = pcall(vim.json.decode, data) ---@type boolean, Stats
  if not (ok and Util.is_type('table', stats)) then
    -- Backup corrupted file
    local backup = ('%s.backup.%s'):format(path, os.time())
    local backup_fd = uv.fs_open(backup, 'w', tonumber('644', 8))
    if not backup_fd then
      return M.default_stats()
    end

    local bytes = uv.fs_write(backup_fd, lines)
    uv.fs_close(backup_fd)

    if not bytes then
      vim.notify(('Corrupted stats could not be backed up to `%s`'):format(backup), WARN)
    end

    if debug then
      vim.notify(('Corrupted stats backed up to `%s`'):format(backup), WARN)
    end

    return M.default_stats()
  end

  -- Fix chars_by_language if it was saved as array
  if stats.chars_by_language and vim.isarray(stats.chars_by_language) then
    stats.chars_by_language = {}
  end

  -- Migrate daily_activity from boolean to number (old format compatibility)
  if stats.daily_activity then
    for date, value in pairs(stats.daily_activity) do
      if Util.is_type('boolean', value) then
        -- Old format: true → 0 (can't recover historical line counts)
        stats.daily_activity[date] = value and 0 or 0
      end
    end
  end

  -- Merge with defaults to ensure all fields exist
  local merged = vim.tbl_deep_extend('force', M.default_stats(), stats)

  -- Recalculate level from XP to fix any inconsistencies
  -- (e.g., if user changed level progression config after playing)
  if not merged.xp or merged.xp <= 0 then
    return merged
  end

  local calculated_level = M.calculate_level(merged.xp)
  if calculated_level ~= merged.level then
    if debug then
      vim.notify(
        ('Level mismatch detected! Recalculating from XP.\nOld level: %d → New level: %d (based on %d XP)'):format(
          merged.level,
          calculated_level,
          merged.xp
        ),
        WARN,
        { title = ' Triforce' }
      )
    end
    merged.level = calculated_level
  end

  return merged
end

---Save stats to disk
---@param stats? Stats
---@param path? string
---@return boolean success
function M.save(stats, path)
  Util.validate({
    stats = { stats, { 'table', 'nil' }, true },
    path = { path, { 'string', 'nil' }, true },
  })
  if not (stats and M.validate_stats(stats)) then
    vim.notify('Unable to save stats!', ERROR)
    return false
  end
  path = (path and Util.is_file(path)) and path or M.get_stats_path()

  local data_to_save = Util.prepare_for_save(stats)
  local ok, json = pcall(vim.json.encode, data_to_save)
  if not (ok and json) then
    vim.notify('Failed to encode stats to JSON', ERROR)
    return false
  end

  local fd
  local file_stat = uv.fs_stat(path)
  if file_stat then
    fd = uv.fs_open(path, 'r', tonumber('644', 8))
    local bak_fd = uv.fs_open(path .. '.bak', 'w', tonumber('644', 8))
    if fd and bak_fd then
      uv.fs_write(bak_fd, uv.fs_read(fd, file_stat.size))
      uv.fs_close(bak_fd)
      uv.fs_close(fd)
    end
  end

  fd = uv.fs_open(path, 'w', tonumber('644', 8))
  if not fd then
    vim.notify(('Failed to write stats file to: %s'):format(vim.fn.fnamemodify(path, ':~')), ERROR)
    return false
  end

  local write_ok = uv.fs_write(fd, json)
  uv.fs_close(fd)
  if not write_ok then
    vim.notify('Failed to write stats file to: ' .. path, ERROR)
    return false
  end
  return true
end

function M.calibrate_tiers()
  if M.calibrated then
    return
  end
  local last_level = M.level_config.tier_1.max_level

  if M.level_config.tier_2.min_level >= last_level then
    M.level_config.tier_2.min_level = last_level + 1
  end
  if M.level_config.tier_2.max_level == math.huge then
    M.level_config.tier_2.max_level = M.level_config.tier_3.min_level - 1
  end
  last_level = M.level_config.tier_2.max_level

  if M.level_config.tier_3.min_level >= last_level then
    M.level_config.tier_3.min_level = last_level + 1
  end
  if M.level_config.tier_3.max_level == math.huge then
    M.level_config.tier_3.max_level = M.level_config.tier_4.min_level - 1
  end
  last_level = M.level_config.tier_3.max_level

  if M.level_config.tier_4.min_level >= last_level then
    M.level_config.tier_4.min_level = last_level + 1
  end
  if M.level_config.tier_4.max_level == math.huge then
    M.level_config.tier_4.max_level = M.level_config.tier_5.min_level - 1
  end
  last_level = M.level_config.tier_4.max_level

  if M.level_config.tier_5.min_level >= last_level then
    M.level_config.tier_5.min_level = last_level + 1
  end
  if M.level_config.tier_5.max_level == math.huge then
    M.level_config.tier_5.max_level = M.level_config.tier_6.min_level - 1
  end
  last_level = M.level_config.tier_5.max_level

  if M.level_config.tier_6.min_level >= last_level then
    M.level_config.tier_6.min_level = last_level + 1
  end
  if M.level_config.tier_6.max_level == math.huge then
    M.level_config.tier_6.max_level = M.level_config.tier_7.min_level - 1
  end
  last_level = M.level_config.tier_6.max_level

  if M.level_config.tier_7.min_level >= last_level then
    M.level_config.tier_7.min_level = last_level + 1
  end
  if M.level_config.tier_7.max_level == math.huge then
    M.level_config.tier_7.max_level = M.level_config.tier_8.min_level - 1
  end
  last_level = M.level_config.tier_7.max_level

  if M.level_config.tier_8.min_level >= last_level then
    M.level_config.tier_8.min_level = last_level + 1
  end
  if M.level_config.tier_8.max_level == math.huge then
    M.level_config.tier_8.max_level = M.level_config.tier_9.min_level - 1
  end
  last_level = M.level_config.tier_8.max_level

  if M.level_config.tier_9.min_level >= last_level then
    M.level_config.tier_9.min_level = last_level + 1
  end
  if M.level_config.tier_9.max_level == math.huge then
    M.level_config.tier_9.max_level = M.level_config.tier_10.min_level - 1
  end
  last_level = M.level_config.tier_9.max_level

  if M.level_config.tier_10.min_level >= last_level then
    M.level_config.tier_10.min_level = last_level + 1
  end
  if M.level_config.tier_10.max_level ~= math.huge then
    M.level_config.tier_10.max_level = math.huge
  end

  M.calibrated = true
end

---Calculate level from XP
---Simple tier-based progression:
---  Levels 1-10: 300 XP each
---  Levels 11-20: 500 XP each
---  Levels 21+: 1000 XP each
---@param xp number
---@return integer level
function M.calculate_level(xp)
  Util.validate({ xp = { xp, { 'number' } } })
  if xp <= 0 then
    return 1
  end

  local level = 1
  local accumulated_xp = 0

  -- Tier 1: Levels 1-10 (300 XP each)
  local tier_1_total = M.level_config.tier_1.max_level * M.level_config.tier_1.xp_per_level
  if xp <= tier_1_total then
    return 1 + math.floor(xp / M.level_config.tier_1.xp_per_level)
  end
  accumulated_xp = tier_1_total
  level = M.level_config.tier_1.max_level

  -- Tier 2: Levels 11-20 (500 XP each)
  local tier_2_range = M.level_config.tier_2.max_level - M.level_config.tier_2.min_level + 1
  local tier_2_total = tier_2_range * M.level_config.tier_2.xp_per_level
  if xp <= accumulated_xp + tier_2_total then
    return (level + 1) + math.floor((xp - accumulated_xp) / M.level_config.tier_2.xp_per_level)
  end
  accumulated_xp = accumulated_xp + tier_2_total
  level = M.level_config.tier_2.max_level

  -- Tier 3: Levels 21-30 (1000 XP each)
  local tier_3_range = M.level_config.tier_3.max_level - M.level_config.tier_3.min_level + 1
  local tier_3_total = tier_3_range * M.level_config.tier_3.xp_per_level
  if xp <= accumulated_xp + tier_3_total then
    return (level + 1) + math.floor((xp - accumulated_xp) / M.level_config.tier_3.xp_per_level)
  end
  accumulated_xp = accumulated_xp + tier_3_total
  level = M.level_config.tier_3.max_level

  -- Tier 4: Levels 31-40 (2000 XP each)
  local tier_4_range = M.level_config.tier_4.max_level - M.level_config.tier_4.min_level + 1
  local tier_4_total = tier_4_range * M.level_config.tier_4.xp_per_level
  if xp <= accumulated_xp + tier_4_total then
    return (level + 1) + math.floor((xp - accumulated_xp) / M.level_config.tier_4.xp_per_level)
  end
  accumulated_xp = accumulated_xp + tier_4_total
  level = M.level_config.tier_4.max_level

  -- Tier 5: Levels 41-50 (3000 XP each)
  local tier_5_range = M.level_config.tier_5.max_level - M.level_config.tier_5.min_level + 1
  local tier_5_total = tier_5_range * M.level_config.tier_5.xp_per_level
  if xp <= accumulated_xp + tier_5_total then
    return (level + 1) + math.floor((xp - accumulated_xp) / M.level_config.tier_5.xp_per_level)
  end
  accumulated_xp = accumulated_xp + tier_5_total
  level = M.level_config.tier_5.max_level

  -- Tier 6: Levels 51-75 (5000 XP each)
  local tier_6_range = M.level_config.tier_6.max_level - M.level_config.tier_6.min_level + 1
  local tier_6_total = tier_6_range * M.level_config.tier_6.xp_per_level
  if xp <= accumulated_xp + tier_6_total then
    return (level + 1) + math.floor((xp - accumulated_xp) / M.level_config.tier_6.xp_per_level)
  end
  accumulated_xp = accumulated_xp + tier_6_total
  level = M.level_config.tier_6.max_level

  -- Tier 7: Levels 76-100 (7500 XP each)
  local tier_7_range = M.level_config.tier_7.max_level - M.level_config.tier_7.min_level + 1
  local tier_7_total = tier_7_range * M.level_config.tier_7.xp_per_level
  if xp <= accumulated_xp + tier_7_total then
    return (level + 1) + math.floor((xp - accumulated_xp) / M.level_config.tier_7.xp_per_level)
  end
  accumulated_xp = accumulated_xp + tier_7_total
  level = M.level_config.tier_7.max_level

  -- Tier 8: Levels 101-150 (10000 XP each)
  local tier_8_range = M.level_config.tier_8.max_level - M.level_config.tier_8.min_level + 1
  local tier_8_total = tier_8_range * M.level_config.tier_8.xp_per_level
  if xp <= accumulated_xp + tier_8_total then
    return (level + 1) + math.floor((xp - accumulated_xp) / M.level_config.tier_8.xp_per_level)
  end
  accumulated_xp = accumulated_xp + tier_8_total
  level = M.level_config.tier_8.max_level

  -- Tier 9: Levels 151-225 (15000 XP each)
  local tier_9_range = M.level_config.tier_9.max_level - M.level_config.tier_9.min_level + 1
  local tier_9_total = tier_9_range * M.level_config.tier_9.xp_per_level
  if xp <= accumulated_xp + tier_9_total then
    return (level + 1) + math.floor((xp - accumulated_xp) / M.level_config.tier_9.xp_per_level)
  end
  accumulated_xp = accumulated_xp + tier_9_total
  level = M.level_config.tier_9.max_level

  -- Tier 10: Levels 226+ (15000 XP each)
  return level + math.floor((xp - accumulated_xp) / M.level_config.tier_10.xp_per_level) + 1
end

---Calculate XP needed for next level
---@param current_level integer
---@return integer xp_needed
function M.xp_for_next_level(current_level)
  return Util.get_total_xp_for_level(current_level + 1, M.level_config)
end

---Add XP and update level
---@param stats Stats
---@param amount number
---@return boolean leveled_up
function M.add_xp(stats, amount)
  Util.validate({
    stats = { stats, { 'table' } },
    amount = { amount, { 'number' } },
  })

  local ft = Util.optget('filetype', 'buf', vim.api.nvim_get_current_buf())
  local keys = vim.tbl_keys(Languages.langs) --[[@as string[]\]]
  if vim.list_contains(Languages.ignored_langs, ft) or not vim.list_contains(keys, ft) then
    return false
  end

  local old_level = stats.level
  stats.xp = stats.xp + amount
  stats.level = M.calculate_level(stats.xp)

  return stats.level > old_level
end

---Start a new session
---@param stats Stats
function M.start_session(stats)
  Util.validate({ stats = { stats, { 'table' } } })

  stats.sessions = stats.sessions + 1
  stats.last_session_start = os.time()
end

---End the current session
---@param stats Stats
function M.end_session(stats)
  Util.validate({ stats = { stats, { 'table' } } })

  -- Time is accumulated per-keystroke in tracker.lua (activity-based),
  -- so we only need to reset the session start marker here.
  stats.last_session_start = 0
end

---Get timestamp for start of day
---@param date_str string Date in YYYY-MM-DD format
local function get_day_start(date_str)
  Util.validate({ date_str = { date_str, { 'string' } } })

  local year, month, day = date_str:match('(%d+)-(%d+)-(%d+)')
  return os.time({ year = year, month = month, day = day, hour = 0, min = 0, sec = 0 })
end

---Calculate streak from daily activity
---@param stats Stats
---@return integer current_streak
---@return integer longest_streak
function M.calculate_streaks(stats)
  Util.validate({ stats = { stats, { 'table' } } })

  if not stats.daily_activity then
    stats.daily_activity = {}
    return 0, 0
  end

  -- Get sorted dates (only those with activity > 0)
  local dates = {}
  for date, lines in pairs(stats.daily_activity) do
    if lines > 0 then
      table.insert(dates, date)
    end
  end
  table.sort(dates)

  if vim.tbl_isempty(dates) then
    return 0, 0
  end

  local current_streak = 0
  local longest_streak = 0
  local streak = 0
  local today = Util.get_date_string()
  local yesterday = Util.get_date_string(os.time() - 86400)

  -- Calculate streaks by iterating through sorted dates
  for i = #dates, 1, -1 do
    local date = dates[i]

    if i == #dates then
      -- Start with most recent date
      if vim.list_contains({ today, yesterday }, date) then
        streak = 1
        current_streak = 1
      end
    else
      local current_time = get_day_start(date)
      local next_time = get_day_start(dates[i + 1])
      local diff_days = math.floor((next_time - current_time) / 86400)

      if diff_days == 1 then
        -- Consecutive day
        streak = streak + 1
        if i == #dates - 1 or vim.list_contains({ today, yesterday }, date) then
          current_streak = streak
        end
      else
        -- Streak broken
        if streak > longest_streak then
          longest_streak = streak
        end
        streak = 1
      end
    end
  end

  -- Check final streak
  if streak > longest_streak then
    longest_streak = streak
  end

  -- If most recent activity wasn't today or yesterday, current streak is 0
  if not vim.list_contains({ today, yesterday }, dates[#dates]) then
    current_streak = 0
  end

  return current_streak, longest_streak
end

---Record activity for today
---@param stats Stats
---@param lines_today integer Number of lines typed today
function M.record_daily_activity(stats, lines_today)
  Util.validate({
    stats = { stats, { 'table' } },
    lines_today = { lines_today, { 'number' } },
  })

  if not stats.daily_activity then
    stats.daily_activity = {}
  end

  local today = Util.get_date_string()
  stats.daily_activity[today] = (stats.daily_activity[today] or 0) + lines_today

  -- Update streaks
  local current, longest = M.calculate_streaks(stats)
  stats.current_streak = current
  stats.longest_streak = longest
end

---Export data to a new empty buffer
---@param stats Stats
function M.export_stats(stats)
  Util.validate({ stats = { stats, { 'table' } } })

  local data = vim.split(vim.inspect(stats), '\n', { plain = true, trimempty = true })
  local bufnr = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, data)

  local win = vim.api.nvim_open_win(bufnr, true, {
    noautocmd = true,
    split = 'below',
    style = 'minimal',
  })

  Util.optset('filetype', 'lua', 'buf', bufnr)
  Util.optset('modified', false, 'buf', bufnr)
  Util.optset('modifiable', false, 'buf', bufnr)

  Util.optset('number', false, 'win', win)
  Util.optset('signcolumn', 'no', 'win', win)
  Util.optset('colorcolumn', '', 'win', win)
  Util.optset('wrap', true, 'win', win)
  Util.optset('list', false, 'win', win)

  vim.keymap.set('n', 'q', function()
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    pcall(vim.api.nvim_win_close, win, true)
  end, { buffer = bufnr })
end

---Export data to a specified JSON file
---@param stats Stats
---@param target string
---@param indent? string
function M.export_to_json(stats, target, indent)
  Util.validate({
    stats = { stats, { 'table' } },
    target = { target, { 'string' } },
    indent = { indent, { 'string', 'nil' }, true },
  })
  target = vim.fn.fnamemodify(target, ':p')
  indent = (indent and indent ~= '') and indent or nil

  local parent_stat = uv.fs_stat(vim.fn.fnamemodify(target, ':h'))
  if not parent_stat or parent_stat.type ~= 'directory' then
    error(('Target not in a valid directory: `%s`'):format(target), ERROR)
  end
  if vim.fn.isdirectory(target) == 1 then
    error(('Target is a directory: `%s`'):format(target), ERROR)
  end

  local fd = uv.fs_open(target, 'w', tonumber('644', 8))
  if not fd then
    error(('Unable to open target `%s`'):format(target), ERROR)
  end

  local ok, data = pcall(vim.json.encode, stats, { sort_keys = true, indent = indent })
  if not (ok and data) then
    uv.fs_close(fd)
    error('Unable to encode stats!', ERROR)
  end

  uv.fs_write(fd, data)
  uv.fs_close(fd)
end

---Export data to a specified Markdown file
---@param stats Stats
---@param target string
function M.export_to_md(stats, target)
  Util.validate({
    stats = { stats, { 'table' } },
    target = { target, { 'string' } },
  })
  target = vim.fn.fnamemodify(target, ':p')

  local parent_stat = uv.fs_stat(vim.fn.fnamemodify(target, ':h'))
  if not parent_stat or parent_stat.type ~= 'directory' then
    error(('Target not in a valid directory: `%s`'):format(target), ERROR)
  end

  if vim.list_contains({ '/', '\\' }, target:sub(-1, -1)) or vim.fn.isdirectory(target) == 1 then
    error(('Target is a directory: `%s`'):format(target), ERROR)
  end

  local fd = uv.fs_open(target, 'w', tonumber('644', 8))
  if not fd then
    error(('Unable to open target `%s`'):format(target), ERROR)
  end

  local data = '# Triforce Stats\n'
  for k, v in pairs(stats) do
    data = ('%s\n## %s\n\n**Value**:'):format(data, k:sub(1, 1):upper() .. k:sub(2))
    if Util.is_type('table', v) then
      data = ('%s\n'):format(data)
      for key, val in pairs(v) do
        data = ('%s- **%s**: `%s`\n'):format(data, key, vim.inspect(val))
      end
    else
      data = ('%s `%s`\n'):format(data, tostring(v))
    end
  end

  uv.fs_write(fd, data)
  uv.fs_close(fd)
end

---Get streak with proper calculation
---@param stats Stats
---@return integer current
function M.get_current_streak(stats)
  local current = M.calculate_streaks(stats)
  return current
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
