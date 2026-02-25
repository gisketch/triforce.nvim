---Stats tracking and persistence module
---@class Stats
---@field xp number Total experience points
---@field level integer Current level
---@field chars_typed integer Total characters typed
---@field lines_typed integer Total lines typed
---@field sessions integer Total sessions
---@field time_coding integer Total time in seconds
---@field last_session_start integer Timestamp of session start
---@field achievements table<string, boolean> Unlocked achievements
---@field chars_by_language table<string, integer> Characters typed per language
---@field daily_activity table<string, integer> Lines typed per day (`YYYY-MM-DD` format)
---@field current_streak integer Current consecutive day streak
---@field longest_streak integer Longest ever streak
---@field db_path string

local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local uv = vim.uv or vim.loop
local Util = require('triforce.util')

---@class Triforce.Stats
---Configurable level progression
---@field level_config LevelProgression
---@field db_path? string
local Stats = {}

Stats.level_config = {
  tier_1 = { min_level = 1, max_level = 10, xp_per_level = 300 }, -- Levels 1-10: 300 XP each
  tier_2 = { min_level = 11, max_level = 20, xp_per_level = 500 }, -- Levels 11-20: 500 XP each
  tier_3 = { min_level = 21, max_level = 30, xp_per_level = 1000 }, -- Levels 21-30: 1000 XP each
  tier_4 = { min_level = 31, max_level = 40, xp_per_level = 2000 }, -- Levels 31-40: 2000 XP each
  tier_5 = { min_level = 41, max_level = 50, xp_per_level = 3000 }, -- Levels 41-50: 3000 XP each
  tier_6 = { min_level = 51, max_level = 75, xp_per_level = 5000 }, -- Levels 51-75: 5000 XP each
  tier_7 = { min_level = 76, max_level = 100, xp_per_level = 7500 }, -- Levels 76-100: 7500 XP each
  tier_8 = { min_level = 101, max_level = math.huge, xp_per_level = 10000 }, -- Levels 101+: 10000 XP each
}

---@return Stats stats
function Stats.default_stats()
  local stats = { ---@type Stats
    xp = 0,
    level = 1,
    chars_typed = 0,
    lines_typed = 0,
    sessions = 0,
    time_coding = 0,
    last_session_start = 0,
    achievements = {},
    chars_by_language = {},
    daily_activity = {},
    current_streak = 0,
    longest_streak = 0,
    db_path = vim.fs.joinpath(vim.fn.stdpath('data'), 'triforce_stats.json'),
  }

  return stats
end

---Get the stats file path
---@return string db_path
function Stats.get_stats_path()
  return Stats.db_path or Stats.default_stats().db_path
end

---@param stats Stats
---@return boolean valid
function Stats.validate_stats(stats)
  Util.validate({ stats = { stats, { 'table' } } })
  if vim.tbl_isempty(stats) or vim.islist(stats) then
    return false
  end

  local keys = vim.tbl_keys(stats) ---@type string[]
  for _, key in ipairs(vim.tbl_keys(Stats.default_stats())) do
    if not vim.list_contains(keys, key) then
      return false
    end
  end
  return true
end

---Load stats from disk
---@param debug? boolean
---@return Stats merged
function Stats.load(debug)
  Util.validate({ debug = { debug, { 'boolean', 'nil' }, true } })
  debug = debug ~= nil and debug or false

  local path = Stats.get_stats_path()
  if vim.fn.filereadable(path) == 0 then
    return Stats.default_stats()
  end

  local lines = vim.fn.readfile(path) ---@type string[]
  if not lines or vim.tbl_isempty(lines) then
    return Stats.default_stats()
  end

  local content = table.concat(lines, '\n')
  local ok, stats = pcall(vim.json.decode, content) ---@type boolean, Stats
  if not (ok and Util.is_type('table', stats)) then
    -- Backup corrupted file
    local backup = ('%s.backup.%s'):format(path, os.time())
    vim.fn.writefile(lines, backup)

    if debug then
      vim.notify('Corrupted stats backed up to: ' .. backup, WARN)
    end

    return Stats.default_stats()
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
  local merged = vim.tbl_deep_extend('force', Stats.default_stats(), stats)

  -- Recalculate level from XP to fix any inconsistencies
  -- (e.g., if user changed level progression config after playing)
  if not merged.xp or merged.xp <= 0 then
    return merged
  end

  local calculated_level = Stats.calculate_level(merged.xp)
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
function Stats.save(stats, path)
  Util.validate({
    stats = { stats, { 'table', 'nil' }, true },
    path = { path, { 'string', 'nil' }, true },
  })
  if not (stats and Stats.validate_stats(stats)) then
    vim.notify('Unable to save stats!', ERROR)
    return false
  end
  path = (path and Util.is_file(path)) and path or Stats.get_stats_path()

  local data_to_save = Util.prepare_for_save(stats)
  local ok, json = pcall(vim.json.encode, data_to_save)
  if not ok then
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

---Calculate level from XP
---Simple tier-based progression:
---  Levels 1-10: 300 XP each
---  Levels 11-20: 500 XP each
---  Levels 21+: 1000 XP each
---@param xp number
---@return integer level
function Stats.calculate_level(xp)
  Util.validate({ xp = { xp, { 'number' } } })
  if xp <= 0 then
    return 1
  end

  local level = 1
  local accumulated_xp = 0

  -- Tier 1: Levels 1-10 (300 XP each)
  local tier_1_total = Stats.level_config.tier_1.max_level * Stats.level_config.tier_1.xp_per_level
  if xp <= tier_1_total then
    return 1 + math.floor(xp / Stats.level_config.tier_1.xp_per_level)
  end
  accumulated_xp = tier_1_total
  level = Stats.level_config.tier_1.max_level

  -- Tier 2: Levels 11-20 (500 XP each)
  local tier_2_range = Stats.level_config.tier_2.max_level - Stats.level_config.tier_2.min_level + 1
  local tier_2_total = tier_2_range * Stats.level_config.tier_2.xp_per_level
  if xp <= accumulated_xp + tier_2_total then
    return (level + 1) + math.floor((xp - accumulated_xp) / Stats.level_config.tier_2.xp_per_level)
  end
  accumulated_xp = accumulated_xp + tier_2_total
  level = Stats.level_config.tier_2.max_level

  -- Tier 3: Levels 21-30 (1000 XP each)
  local tier_3_range = Stats.level_config.tier_3.max_level - Stats.level_config.tier_3.min_level + 1
  local tier_3_total = tier_3_range * Stats.level_config.tier_3.xp_per_level
  if xp <= accumulated_xp + tier_3_total then
    return (level + 1) + math.floor((xp - accumulated_xp) / Stats.level_config.tier_3.xp_per_level)
  end
  accumulated_xp = accumulated_xp + tier_3_total
  level = Stats.level_config.tier_3.max_level
  
  -- Tier 4: Levels 31-40 (2000 XP each)
  local tier_4_range = Stats.level_config.tier_4.max_level - Stats.level_config.tier_4.min_level + 1
  local tier_4_total = tier_4_range * Stats.level_config.tier_4.xp_per_level
  if xp <= accumulated_xp + tier_4_total then
    return (level + 1) + math.floor((xp - accumulated_xp) / Stats.level_config.tier_4.xp_per_level)
  end
  accumulated_xp = accumulated_xp + tier_4_total
  level = Stats.level_config.tier_4.max_level

  -- Tier 5: Levels 41-50 (3000 XP each)
  local tier_5_range = Stats.level_config.tier_5.max_level - Stats.level_config.tier_5.min_level + 1
  local tier_5_total = tier_5_range * Stats.level_config.tier_5.xp_per_level
  if xp <= accumulated_xp + tier_5_total then
    return (level + 1) + math.floor((xp - accumulated_xp) / Stats.level_config.tier_5.xp_per_level)
  end
  accumulated_xp = accumulated_xp + tier_5_total
  level = Stats.level_config.tier_5.max_level

  -- Tier 6: Levels 51-75 (5000 XP each)
  local tier_6_range = Stats.level_config.tier_6.max_level - Stats.level_config.tier_6.min_level + 1
  local tier_6_total = tier_6_range * Stats.level_config.tier_6.xp_per_level
  if xp <= accumulated_xp + tier_6_total then
    return (level + 1) + math.floor((xp - accumulated_xp) / Stats.level_config.tier_6.xp_per_level)
  end
  accumulated_xp = accumulated_xp + tier_6_total
  level = Stats.level_config.tier_6.max_level

  -- Tier 7: Levels 76-100 (7500 XP each)
  local tier_7_range = Stats.level_config.tier_7.max_level - Stats.level_config.tier_7.min_level + 1
  local tier_7_total = tier_7_range * Stats.level_config.tier_7.xp_per_level
  if xp <= accumulated_xp + tier_7_total then
    return (level + 1) + math.floor((xp - accumulated_xp) / Stats.level_config.tier_7.xp_per_level)
  end
  accumulated_xp = accumulated_xp + tier_7_total
  level = Stats.level_config.tier_7.max_level

  -- Tier 8: Levels 101+ (10000 XP each)
  return level + math.floor((xp - accumulated_xp) / Stats.level_config.tier_8.xp_per_level) + 1
end

---Calculate XP needed for next level
---@param current_level integer
---@return integer xp_needed
function Stats.xp_for_next_level(current_level)
  return Util.get_total_xp_for_level(current_level + 1, Stats.level_config)
end

---Add XP and update level
---@param stats Stats
---@param amount number
---@return boolean leveled_up
function Stats.add_xp(stats, amount)
  Util.validate({
    stats = { stats, { 'table' } },
    amount = { amount, { 'number' } },
  })

  local ft = vim.api.nvim_get_option_value('filetype', { buf = vim.api.nvim_get_current_buf() })
  local langs_module = require('triforce.languages')
  local keys = vim.tbl_keys(langs_module.langs) ---@type string[]
  if vim.list_contains(langs_module.ignored_langs, ft) or not vim.list_contains(keys, ft) then
    return false
  end

  local old_level = stats.level
  stats.xp = stats.xp + amount
  stats.level = Stats.calculate_level(stats.xp)

  return stats.level > old_level
end

---Start a new session
---@param stats Stats
function Stats.start_session(stats)
  Util.validate({ stats = { stats, { 'table' } } })

  stats.sessions = stats.sessions + 1
  stats.last_session_start = os.time()
end

---End the current session
---@param stats Stats
function Stats.end_session(stats)
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
function Stats.calculate_streaks(stats)
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
function Stats.record_daily_activity(stats, lines_today)
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
  local current, longest = Stats.calculate_streaks(stats)
  stats.current_streak = current
  stats.longest_streak = longest
end

---Export data to a new empty buffer
---@param stats Stats
function Stats.export_stats(stats)
  Util.validate({ stats = { stats, { 'table' } } })

  local data = vim.split(vim.inspect(stats), '\n', { plain = true, trimempty = true })
  local bufnr = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, data)

  local win = vim.api.nvim_open_win(bufnr, true, {
    noautocmd = true,
    split = 'below',
    style = 'minimal',
  })

  ---@type vim.api.keyset.option, vim.api.keyset.option
  local buf_opts, win_opts = { buf = bufnr }, { win = win }
  vim.api.nvim_set_option_value('filetype', 'lua', buf_opts)
  vim.api.nvim_set_option_value('modified', false, buf_opts)
  vim.api.nvim_set_option_value('modifiable', false, buf_opts)

  vim.api.nvi_set_option_value('number', false, win_opts)
  vim.api.nvi_set_option_value('signcolumn', 'no', win_opts)
  vim.api.nvi_set_option_value('colorcolumn', '', win_opts)
  vim.api.nvi_set_option_value('wrap', true, win_opts)
  vim.api.nvi_set_option_value('list', false, win_opts)

  vim.keymap.set('n', 'q', function()
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    pcall(vim.api.nvim_win_close, win, true)
  end, { noremap = true, silent = true, buffer = bufnr })
end

---Export data to a specified JSON file
---@param stats Stats
---@param target string
---@param indent? string
function Stats.export_to_json(stats, target, indent)
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
  if not ok then
    uv.fs_close(fd)
    error('Unable to encode stats!', ERROR)
  end

  uv.fs_write(fd, data)
  uv.fs_close(fd)
end

---Export data to a specified Markdown file
---@param stats Stats
---@param target string
function Stats.export_to_md(stats, target)
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
function Stats.get_current_streak(stats)
  local current = Stats.calculate_streaks(stats)
  return current
end

return Stats
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
