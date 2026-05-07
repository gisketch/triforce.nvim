---@module 'triforce.types'

local ERROR = vim.log.levels.ERROR

---@enum DaysPerMonth
local DAYS_PER_MONTH = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

---Various utilities to be used for Triforce
---@class Triforce.Util
local M = {}

---Checks if module `mod` exists to be imported.
--- ---
---@param mod string The `require()` argument to be checked
---@return boolean exists A boolean indicating whether the module exists or not
---@nodiscard
function M.mod_exists(mod)
  M.validate({ mod = { mod, { 'string' } } })

  if mod == '' then
    return false
  end
  local exists = pcall(require, mod)
  return exists
end

---@overload fun(option: string|vim.wo|vim.bo): value: any
---@overload fun(option: string|vim.wo|vim.bo, param: 'scope', param_value: 'local'|'global'): value: any
---@overload fun(option: string|vim.wo|vim.bo, param: 'ft', param_value: string): value: any
---@overload fun(option: string|vim.wo|vim.bo, param: 'buf'|'win', param_value: integer): value: any
function M.optget(option, param, param_value)
  M.validate({
    option = { option, { 'string' } },
    param = { param, { 'string', 'nil' }, true },
    param_value = { param_value, { 'string', 'number', 'nil' }, true },
  })
  param = param or 'buf'
  if not vim.list_contains({ 'scope', 'ft', 'buf', 'win' }, param) then
    error(('Bad parameter: `%s`\nCan only accept `scope`, `ft`, `buf` or `win`!'):format(vim.inspect(param)), ERROR)
  end
  if param == 'scope' then
    param_value = param_value or 'local'
    if not vim.list_contains({ 'global', 'local' }, param_value) then
      error(('Bad param value `%s`\nCan only accept `global` or `local`!'):format(vim.inspect(param_value)), ERROR)
    end
  end
  if param == 'ft' and (not param_value or type(param_value) ~= 'string') then
    error('Missing/bad value for `ft` parameter!', ERROR)
  end
  if
    vim.list_contains({ 'win', 'buf' }, param)
    and not (param_value and type(param_value) == 'number' and M.is_int(param_value, param_value >= 0))
  then
    error('Missing/bad value for `win`/`buf` parameter!', ERROR)
  end

  return vim.api.nvim_get_option_value(option, { [param] = param_value })
end

---@overload fun(option: string|vim.wo|vim.bo, value: any)
---@overload fun(option: string|vim.wo|vim.bo, value: any, param: 'scope', param_value: 'local'|'global')
---@overload fun(option: string|vim.wo|vim.bo, value: any, param: 'ft', param_value: string)
---@overload fun(option: string|vim.wo|vim.bo, value: any, param: 'buf'|'win', param_value: integer)
function M.optset(option, value, param, param_value)
  M.validate({
    option = { option, { 'string' } },
    param = { param, { 'string', 'nil' }, true },
    param_value = { param_value, { 'string', 'number', 'nil' }, true },
  })
  if value == nil then
    error('Empty option value is unacceptable!', ERROR)
  end
  param = param or 'buf'
  if not vim.list_contains({ 'scope', 'ft', 'buf', 'win' }, param) then
    error(('Bad parameter: `%s`\nCan only accept `scope`, `ft`, `buf` or `win`!'):format(vim.inspect(param)), ERROR)
  end
  if param == 'scope' then
    param_value = param_value or 'local'
    if not vim.list_contains({ 'global', 'local' }, param_value) then
      error(('Bad param value `%s`\nCan only accept `global` or `local`!'):format(vim.inspect(param_value)), ERROR)
    end
  end
  if param == 'ft' and (not param_value or type(param_value) ~= 'string') then
    error('Missing/bad value for `ft` parameter!', ERROR)
  end
  if
    vim.list_contains({ 'win', 'buf' }, param)
    and not (param_value and type(param_value) == 'number' and M.is_int(param_value, param_value >= 0))
  then
    error('Missing/bad value for `win`/`buf` parameter!', ERROR)
  end

  vim.api.nvim_set_option_value(option, value, { [param] = param_value })
end

---@param day integer
---@return string formatted_str
function M.double_digits(day)
  return ('%02d'):format(day)
end

---Checks whether `data` is of type `t` or not.
---
---If `data` is `nil`, the function will always return `false`.
---@param t type Any return value the `type()` function would return
---@param data any The data to be type-checked
---@return boolean check
function M.is_type(t, data)
  return data ~= nil and type(data) == t
end

---@param feature string
---@return boolean has
function M.vim_has(feature)
  return vim.fn.has(feature) == 1
end

---Dynamic `vim.validate()` wrapper. Covers both legacy and newer implementations
---@param T table<string, vim.validate.Spec|ValidateSpec>
function M.validate(T)
  local max = M.vim_has('nvim-0.11') and 3 or 4
  for name, spec in pairs(T) do
    while #spec > max do
      table.remove(spec, #spec)
    end
    T[name] = spec
  end

  if M.vim_has('nvim-0.11') then
    for name, spec in pairs(T) do
      table.insert(spec, 1, name)
      vim.validate(unpack(spec))
    end
    return
  end

  vim.validate(T)
end

---Emulates the behaviour of Python's builtin `range()` function.
---@overload fun(x: integer): range_list: integer[]
---@overload fun(x: integer, y: integer): range_list: integer[]
---@overload fun(x: integer, y: integer, step: integer): range_list: integer[]
function M.range(x, y, step)
  M.validate({
    x = { x, { 'number' } },
    y = { y, { 'number', 'nil' }, true },
    step = { step, { 'number', 'nil' }, true },
  })

  if not M.is_int(x) then
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
    if not M.is_int(y) then
      error(('Argument `y` is not an integer: `%s`'):format(y), ERROR)
    end
    step = x <= y and 1 or -1

    table.insert(range_list, x)
    for v = x + step, y, step do
      table.insert(range_list, v)
    end
  elseif y and step then
    if not M.is_int({ y, step }) then
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
---@return boolean leap_year
function M.is_leap(year)
  M.validate({ year = { year, { 'number' } } })
  if not M.is_int(year) then
    error(('Not an integer: `%s`'):format(year), ERROR)
  end

  return (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
end

---@param month Months
---@param year integer
---@return integer days
function M.days_in_month(month, year)
  M.validate({
    month = { month, { 'number' } },
    year = { year, { 'number' } },
  })

  if not (M.is_int(month) and vim.list_contains(M.range(12), month)) then
    error('Cannot calculate days in month!', ERROR)
  end

  if month ~= 2 then
    return DAYS_PER_MONTH[month]
  end
  return M.is_leap(year) and 29 or 28
end

---Get current date in YYYY-MM-DD format
---@param timestamp? integer Optional timestamp, defaults to current time
---@return string date_str
function M.get_date_string(timestamp)
  M.validate({ timestamp = { timestamp, { 'number', 'nil' }, true } })

  return os.date('%Y-%m-%d', timestamp or os.time())
end

---Get XP rewards from config
---@return XPRewards rewards
function M.get_xp_rewards()
  return require('triforce.config').config.xp_rewards or { char = 1, line = 1, save = 50 }
end

---Prepare stats for JSON encoding (handle empty tables)
---@param stats Stats
---@return Stats copy
function M.prepare_for_save(stats)
  M.validate({ stats = { stats, { 'table' } } })

  local copy = vim.deepcopy(stats)

  copy.achievements = vim.tbl_isempty(copy.achievements) and vim.empty_dict() or copy.achievements
  copy.chars_by_language = vim.tbl_isempty(copy.chars_by_language) and vim.empty_dict() or copy.chars_by_language
  copy.daily_activity = vim.tbl_isempty(copy.daily_activity) and vim.empty_dict() or copy.daily_activity
  return copy
end

---@generic T
---@param x T[]|T
---@param cond? boolean
---@return boolean int
function M.is_int(x, cond)
  M.validate({
    x = { x, { 'table', 'number' } },
    cond = { cond, { 'boolean', 'nil' }, true },
  })
  if cond == nil then
    cond = true
  end

  if M.is_type('number', x) then
    ---@cast x number
    return x == math.floor(x) and x == math.ceil(x) and cond
  end

  if vim.tbl_isempty(x) then
    return false
  end

  for _, val in ipairs(x) do
    if not M.is_int(val) then
      return false
    end
  end

  return cond
end

---@generic T: table
---@param T T
---@return boolean dict
function M.is_dict(T)
  M.validate({ T = { T, { 'table' } } })

  return not (vim.tbl_isempty(T) or vim.islist(T))
end

---Calculate total XP needed to reach a specific level
---@param level integer
---@param level_config LevelProgression
---@return integer total_xp
function M.get_total_xp_for_level(level, level_config)
  M.validate({
    level = { level, { 'number' } },
    level_config = { level_config, { 'table' } },
    ['level_config.tier_1'] = { level_config.tier_1, { 'table' } },
    ['level_config.tier_2'] = { level_config.tier_2, { 'table' } },
    ['level_config.tier_3'] = { level_config.tier_3, { 'table' } },
    ['level_config.tier_4'] = { level_config.tier_4, { 'table' } },
    ['level_config.tier_5'] = { level_config.tier_5, { 'table' } },
    ['level_config.tier_6'] = { level_config.tier_6, { 'table' } },
    ['level_config.tier_7'] = { level_config.tier_7, { 'table' } },
    ['level_config.tier_8'] = { level_config.tier_8, { 'table' } },
    ['level_config.tier_9'] = { level_config.tier_9, { 'table' } },
    ['level_config.tier_10'] = { level_config.tier_10, { 'table' } },
  })

  for name, tier in pairs(level_config) do
    ---@cast tier LevelTier|LevelTier10
    M.validate({
      [('%s_max_level'):format(name)] = { tier.max_level, { 'number' } },
      [('%s_min_level'):format(name)] = { tier.min_level, { 'number' } },
      [('%s_xp_per_level'):format(name)] = { tier.xp_per_level, { 'number' } },
    })
  end
  if level <= 1 then
    return 0
  end

  local total_xp = 0
  if level > level_config.tier_1.min_level then
    total_xp = total_xp + (math.min(level - 1, level_config.tier_1.max_level) * level_config.tier_1.xp_per_level)
  end

  if level > level_config.tier_2.min_level then
    local tier_2_levels = math.min(level - 1, level_config.tier_2.max_level) - level_config.tier_2.min_level + 1
    if tier_2_levels > 0 then
      total_xp = total_xp + (tier_2_levels * level_config.tier_2.xp_per_level)
    end
  end

  if level > level_config.tier_3.min_level then
    local tier_3_levels = math.min(level - 1, level_config.tier_3.max_level) - level_config.tier_3.min_level + 1
    if tier_3_levels > 0 then
      total_xp = total_xp + (tier_3_levels * level_config.tier_3.xp_per_level)
    end
  end

  if level > level_config.tier_4.min_level then
    local tier_4_levels = math.min(level - 1, level_config.tier_4.max_level) - level_config.tier_4.min_level + 1
    if tier_4_levels > 0 then
      total_xp = total_xp + (tier_4_levels * level_config.tier_4.xp_per_level)
    end
  end

  if level > level_config.tier_5.min_level then
    local tier_5_levels = math.min(level - 1, level_config.tier_5.max_level) - level_config.tier_5.min_level + 1
    if tier_5_levels > 0 then
      total_xp = total_xp + (tier_5_levels * level_config.tier_5.xp_per_level)
    end
  end

  if level > level_config.tier_6.min_level then
    local tier_6_levels = math.min(level - 1, level_config.tier_6.max_level) - level_config.tier_6.min_level + 1
    if tier_6_levels > 0 then
      total_xp = total_xp + (tier_6_levels * level_config.tier_6.xp_per_level)
    end
  end

  if level > level_config.tier_7.min_level then
    local tier_7_levels = math.min(level - 1, level_config.tier_7.max_level) - level_config.tier_7.min_level + 1
    if tier_7_levels > 0 then
      total_xp = total_xp + (tier_7_levels * level_config.tier_7.xp_per_level)
    end
  end

  if level > level_config.tier_8.min_level then
    local tier_8_levels = math.min(level - 1, level_config.tier_8.max_level) - level_config.tier_8.min_level + 1
    if tier_8_levels > 0 then
      total_xp = total_xp + (tier_8_levels * level_config.tier_8.xp_per_level)
    end
  end

  if level > level_config.tier_9.min_level then
    local tier_9_levels = math.min(level - 1, level_config.tier_9.max_level) - level_config.tier_9.min_level + 1
    if tier_9_levels > 0 then
      total_xp = total_xp + (tier_9_levels * level_config.tier_9.xp_per_level)
    end
  end

  if level > level_config.tier_10.min_level then
    total_xp = total_xp + ((level - level_config.tier_10.min_level) * level_config.tier_10.xp_per_level)
  end

  return total_xp
end

---Format seconds to readable time
---@param secs integer
---@return string time
function M.format_time(secs)
  return ('%dh %dm'):format(math.floor(secs / 3600), math.floor((secs % 3600) / 60))
end

---Helper functions (copied from typr)
---@param day integer
---@param month Months
---@param year integer
---@return integer day_i
function M.getday_i(day, month, year)
  return tonumber(os.date('%w', os.time({ year = tostring(year), month = month, day = day })), 10) + 1
end

---@param curr integer
---@param first integer
---@param last integer
---@param back? boolean
---@return integer cycled
function M.cycle_range(curr, first, last, back)
  M.validate({
    curr = { curr, { 'number' } },
    first = { first, { 'number' } },
    last = { last, { 'number' } },
    back = { back, { 'boolean', 'nil' }, true },
  })
  if back == nil then
    back = false
  end

  if not M.is_int({ curr, first, last }) then
    error('Value is not an integer!', ERROR)
  end

  if last < first then
    first, last = M.swap(first, last)
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

---Swap two values, then return them afterwards
---@generic T, U
---@param x T
---@param y U
---@return U x
---@return T y
function M.swap(x, y)
  x, y = y, x
  return x, y
end

---@param path string
---@param writable? boolean
---@return boolean file
function M.is_file(path, writable)
  M.validate({
    path = { path, { 'string' } },
    writable = { writable, { 'boolean', 'nil' }, true },
  })
  if writable == nil then
    writable = false
  end

  if writable then
    return vim.fn.filereadable(path) == 1 and vim.fn.filewritable(path) == 1
  end
  return vim.fn.filereadable(path) == 1
end

local Util = setmetatable(M, {
  __index = M,
  __newindex = function()
    error('`triforce.util` is read-only!', ERROR)
  end,
})

return Util
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
