---Non-legacy validation spec (>=v0.11)
---@class ValidateSpec
---@field [1] any
---@field [2] vim.validate.Validator
---@field [3]? boolean
---@field [4]? string

---@alias Months 1|2|3|4|5|6|7|8|9|10|11|12

local ERROR = vim.log.levels.ERROR
local uv = vim.uv or vim.loop

---Various utilities to be used for Triforce
---@class Triforce.Util
local Util = {}

---Checks whether `data` is of type `t` or not.
---
---If `data` is `nil`, the function will always return `false`.
---@param t type Any return value the `type()` function would return
---@param data any The data to be type-checked
---@return boolean check
function Util.is_type(t, data)
  return data ~= nil and type(data) == t
end

---@param feature string
---@return boolean has
function Util.vim_has(feature)
  return vim.fn.has(feature) == 1
end

---Dynamic `vim.validate()` wrapper. Covers both legacy and newer implementations
---@param T table<string, vim.validate.Spec|ValidateSpec>
function Util.validate(T)
  local max = vim.fn.has('nvim-0.11') == 1 and 3 or 4
  for name, spec in pairs(T) do
    while #spec > max do
      table.remove(spec, #spec)
    end

    T[name] = spec
  end

  for name, spec in pairs(T) do
    if vim.fn.has('nvim-0.11') == 1 then
      table.insert(spec, 1, name)
      vim.validate(unpack(spec))
    else
      vim.validate(spec)
    end
  end
end

---Emulates the behaviour of Python's builtin `range()` function.
---@param x integer
---@param y integer
---@param step integer
---@return integer[] range_list
---@overload fun(x: integer): range_list: integer[]
---@overload fun(x: integer, y: integer): range_list: integer[]
function Util.range(x, y, step)
  Util.validate({
    x = { x, { 'number' } },
    y = { y, { 'number', 'nil' }, true },
    step = { step, { 'number', 'nil' }, true },
  })

  if not Util.is_int(x) then
    error(('Argument `x` is not an integer: `%s`'):format(x), ERROR)
  end

  local range_list = {} ---@type integer[]
  if not (y or step) then
    y = x
    x = 1
    step = x <= y and 1 or -1

    table.insert(range_list, x)
    for v = x + step, y, step do
      table.insert(range_list, v)
    end
  elseif y and not step then
    if not Util.is_int(y) then
      error(('Argument `y` is not an integer: `%s`'):format(y), ERROR)
    end
    step = x <= y and 1 or -1

    table.insert(range_list, x)
    for v = x + step, y, step do
      table.insert(range_list, v)
    end
  elseif y and step then
    if not Util.is_int({ y, step }) then
      error('Arguments `y` and/or `step` are not an integer!', ERROR)
    end
    if step == 0 then
      error('Argument `step` cannot be `0`!', ERROR)
    end
    if x > y and step >= 1 then
      error('Index out of bounds!', ERROR)
    end
    if x > y and step <= -1 then
      local p = x
      x = y
      y = p
      step = step * -1
    end

    table.insert(range_list, x)
    for v = x + step, y, step do
      table.insert(range_list, v)
    end
  else
    error(('Argument `y` is nil while `step` is not: `%s`'):format(step), ERROR)
  end

  table.sort(range_list)
  return range_list
end

---@param year integer
---@return boolean leap
function Util.is_leap_year(year)
  return (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
end

---@param month Months
---@param year integer
---@return integer days
function Util.days_in_month(month, year)
  Util.validate({
    month = { month, { 'number' } },
    year = { year, { 'number' } },
  })

  if not vim.list_contains(Util.range(12), month) then
    error('Cannot calculate days in month!', ERROR)
  end

  local days_in_months = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  if month ~= 2 then
    return days_in_months[month]
  end
  return Util.is_leap_year(year) and 29 or 28
end

---Get current date in YYYY-MM-DD format
---@param timestamp integer Optional timestamp, defaults to current time
---@return string date_str
---@overload fun(): date_str: string
function Util.get_date_string(timestamp)
  Util.validate({ timestamp = { timestamp, { 'number', 'nil' }, true } })

  return os.date('%Y-%m-%d', timestamp or os.time())
end

---Get XP rewards from config
---@return XPRewards rewards
function Util.get_xp_rewards()
  return require('triforce.config').config.xp_rewards or { char = 1, line = 1, save = 50 }
end

---Prepare stats for JSON encoding (handle empty tables)
---@param stats Stats
---@return Stats copy
function Util.prepare_for_save(stats)
  Util.validate({ stats = { stats, { 'table' } } })

  local copy = vim.deepcopy(stats)

  -- Use `vim.empty_dict()` to ensure empty tables encode as `{}` not `[]`
  if vim.tbl_isempty(copy.achievements) then
    copy.achievements = vim.empty_dict()
  end

  if vim.tbl_isempty(copy.chars_by_language) then
    copy.chars_by_language = vim.empty_dict()
  end

  if vim.tbl_isempty(copy.daily_activity) then
    copy.daily_activity = vim.empty_dict()
  end

  return copy
end

---@param x number[]|number
---@return boolean int
---@overload fun(x: number): int: boolean
---@overload fun(x: number[]): int: boolean
function Util.is_int(x)
  Util.validate({ x = { x, { 'table', 'number' } } })

  ---@cast x number[]
  if Util.is_type('table', x) then
    if vim.tbl_isempty(x) then
      return false
    end

    local int = true
    for _, val in ipairs(x) do
      if not Util.is_int(val) then
        int = false
        break
      end
    end

    return int
  end

  ---@cast x number
  return (math.ceil(x) == x or math.floor(x) == x)
end

---@param T table
---@return boolean dict
function Util.is_dict(T)
  Util.validate({ T = { T, { 'table' } } })

  if vim.tbl_isempty(T) then
    return false
  end

  for k, _ in pairs(T) do
    if Util.is_type('string', k) or not Util.is_int(k) then
      return true
    end
  end

  return false
end

---Calculate total XP needed to reach a specific level
---@param level integer
---@param level_config LevelProgression
---@return integer total_xp
function Util.get_total_xp_for_level(level, level_config)
  Util.validate({
    level = { level, { 'number' } },
    level_config = { level_config, { 'table' } },
  })

  if level <= 1 then
    return 0
  end

  local total_xp = 0

  -- Calculate XP for tier 1 (levels 1-10)
  if level > level_config.tier_1.min_level then
    total_xp = total_xp + (math.min(level - 1, level_config.tier_1.max_level) * level_config.tier_1.xp_per_level)
  end

  -- Calculate XP for tier 2 (levels 11-20)
  if level > level_config.tier_2.min_level then
    local tier_2_levels = math.min(level - 1, level_config.tier_2.max_level) - level_config.tier_2.min_level + 1
    if tier_2_levels > 0 then
      total_xp = total_xp + (tier_2_levels * level_config.tier_2.xp_per_level)
    end
  end

  -- Calculate XP for tier 3 (levels 21+)
  if level > level_config.tier_3.min_level then
    total_xp = total_xp + ((level - level_config.tier_3.min_level) * level_config.tier_3.xp_per_level)
  end

  return total_xp
end

---Format seconds to readable time
---@param secs number
---@return string time
function Util.format_time(secs)
  return ('%dh %dm'):format(math.floor(secs / 3600), math.floor((secs % 3600) / 60))
end

---Helper functions (copied from typr)
---@param day integer
---@param month Months
---@param year integer
---@return number day_i
function Util.getday_i(day, month, year)
  return tonumber(os.date('%w', os.time({ year = tostring(year), month = month, day = day }))) + 1
end

---@param day integer
---@return string formatted_str
function Util.double_digits(day)
  return (day >= 10 and '%s' or '0%s'):format(day)
end

---@param curr integer
---@param first integer
---@param last integer
---@param back boolean
---@return integer cycled
---@overload fun(curr: integer, first: integer, last: integer): cycled: integer
function Util.cycle_range(curr, first, last, back)
  Util.validate({
    curr = { curr, { 'number' } },
    first = { first, { 'number' } },
    last = { last, { 'number' } },
    back = { back, { 'boolean', 'nil' }, true },
  })
  back = back ~= nil and back or false

  if not Util.is_int({ curr, first, last }) then
    error('Value is not an integer!', ERROR)
  end

  if last < first then
    first, last = last, first
  end

  if curr > last or curr < first then
    error('Number to be cycled is out of range!', ERROR)
  end

  local cycled = curr + 1 > last and first or curr + 1
  if back then
    cycled = curr - 1 < first and last or curr - 1
  end

  return cycled
end

---@param path string
---@return boolean file
function Util.is_file(path)
  Util.validate({ path = { path, { 'string' } } })

  return vim.fn.filereadable(path) == 1
end

---@param fname string
---@param flags string
---@param mode integer
---@return integer fd
---@return uv.fs_stat.result|nil stat
---@overload fun(fname: string, flags: string): fd: integer, stat: uv.fs_stat.result|nil
function Util.open_file(fname, flags, mode)
  Util.validate({
    fname = { fname, { 'string' } },
    flags = { flags, { 'string' } },
    mode = { mode, { 'number', 'nil' }, true },
  })
  mode = mode or tonumber('644', 8)

  local stat = uv.fs_stat(fname)
  local fd = uv.fs_open(fname, flags, mode)
  if not fd then -- Check if file could be opened
    error('File descriptor unavailable!', ERROR)
  end

  return fd, stat
end

return Util
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
