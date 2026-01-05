---Non-legacy validation spec (>=v0.11)
---@class ValidateSpec
---@field [1] any
---@field [2] vim.validate.Validator
---@field [3]? boolean
---@field [4]? string

local ERROR = vim.log.levels.ERROR

---Various utilities to be used for Triforce
---@class Triforce.Util
local Util = {}

---Dynamic `vim.validate()` wrapper. Covers both legacy and newer implementations
---@param T table<string, vim.validate.Spec|ValidateSpec>
function Util.validate(T)
  if vim.fn.has('nvim-0.11') ~= 1 then
    vim.validate({ T = { T, { 'table' } } })
  else
    vim.validate('T', T, { 'table' }, false)
  end

  if vim.fn.has('nvim-0.11') ~= 1 then
    ---Filter table to fit legacy standard
    ---@cast T table<string, vim.validate.Spec>
    for name, spec in pairs(T) do
      while #spec > 3 do
        table.remove(spec, #spec)
      end

      T[name] = spec
    end

    vim.validate(T)
    return
  end

  ---Filter table to fit non-legacy standard
  ---@cast T table<string, ValidateSpec>
  for name, spec in pairs(T) do
    while #spec > 4 do
      table.remove(spec, #spec)
    end

    T[name] = spec
  end

  for name, spec in pairs(T) do
    table.insert(spec, 1, name)
    vim.validate(unpack(spec))
  end
end

---Get current date in YYYY-MM-DD format
---@param timestamp? integer Optional timestamp, defaults to current time
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
function Util.is_int(x)
  Util.validate({ x = { x, { 'table', 'number' } } })

  ---@cast x number[]
  if type(x) == 'table' then
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
    if type(k) == 'string' or not Util.is_int(k) then
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
---@return number day_i
function Util.getday_i(day, month, year)
  return tonumber(os.date('%w', os.time({ year = tostring(year), month = month, day = day }))) + 1
end

---@return string formatted_str
function Util.double_digits(day)
  return (day >= 10 and '%s' or '0%s'):format(day)
end

---@param curr integer
---@param first integer
---@param last integer
---@param back? boolean
---@return integer cycled
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

return Util
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
