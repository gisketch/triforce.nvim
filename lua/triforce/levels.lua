---@module 'triforce.types'

local ERROR = vim.log.levels.ERROR
local Util = require('triforce.util')

---@return LevelTitles titles
local function get_default_titles()
  local titles = { ---@type LevelTitles
    [10] = { title = 'Deku Scrub', icon = '🌱' },
    [20] = { title = 'Kokiri', icon = '🌳' },
    [30] = { title = 'Hylian Soldier', icon = '🗡️' },
    [40] = { title = 'Knight', icon = '⚔️' },
    [50] = { title = 'Royal Guard', icon = '🛡️' },
    [60] = { title = 'Master Swordsman', icon = '⚡' },
    [70] = { title = 'Hero of Time', icon = '🔺' },
    [80] = { title = 'Sage', icon = '✨' },
    [90] = { title = 'Triforce Bearer', icon = '🔱' },
    [100] = { title = 'Champion', icon = '👑' },
    [120] = { title = 'Divine Beast Pilot', icon = '🦅' },
    [150] = { title = 'Ancient Hero', icon = '🏛️' },
    [180] = { title = 'Legendary Warrior', icon = '⚜️' },
    [200] = { title = 'Goddess Chosen', icon = '🌟' },
    [250] = { title = 'Demise Slayer', icon = '💀' },
    [300] = { title = 'Eternal Legend', icon = '💫' },
  }

  return titles
end

---@class Triforce.Levels
---@field levels LevelTitles
local M = {}

M.levels = {}

---@param override? boolean
function M.setup(override)
  Util.validate({ override = { override, { 'boolean', 'nil' }, true } })
  if override == nil then
    override = false
  end

  if not override then
    M.levels = vim.tbl_deep_extend('keep', M.levels, get_default_titles())
  end
end

---@param levels LevelParams[]|LevelParams
function M.add_levels(levels)
  Util.validate({ levels = { levels, { 'table' } } })
  if vim.tbl_isempty(levels) then
    return
  end

  ---@cast levels LevelParams[]
  if vim.islist(levels) then
    for _, lvl in ipairs(levels) do
      M.add_levels(lvl)
    end
    return
  end

  ---@cast levels LevelParams
  Util.validate({
    levels_level = { levels.level, { 'number' } },
    levels_title = { levels.title, { 'string' } },
    levels_icon = { levels.icon, { 'string', 'nil' }, true },
  })

  M.levels[levels.level] = { title = levels.title, icon = levels.icon or '' }
end

---@param stats Stats
---@return LevelSpec[] all_levels
function M.get_all_levels(stats)
  Util.validate({ stats = { stats, { 'table' } } })

  local keys = vim.tbl_keys(M.levels) --[[@as integer[]\]]
  local res = {} ---@type LevelSpec[]
  for _, lvl in ipairs(keys) do
    local title = M.get_level_title(lvl)
    if title ~= '' then
      table.insert(res, { level = lvl, unlocked = lvl <= stats.level, title = title })
    end
  end
  return res
end

---Get icon based on given level
---@param level integer
---@return string icon
function M.get_level_icon(level)
  Util.validate({ level = { level, { 'number' } } })
  if not Util.is_int(level, level > 0) then
    error(('Level `%s` is not valid!'):format(vim.inspect(level)), ERROR)
  end

  if vim.tbl_isempty(M.levels) then
    return ''
  end

  local values = {} ---@type integer[]
  for k in pairs(M.levels) do
    if level - k <= 0 then
      table.insert(values, k)
    end
  end
  return M.levels[math.min(unpack(values))].icon or '💫'
end

---Get title based on given level
---@param level integer
---@param with_icon? boolean
---@return string title
function M.get_level_title(level, with_icon)
  Util.validate({
    level = { level, { 'number' } },
    with_icon = { with_icon, { 'boolean', 'nil' }, true },
  })
  if not Util.is_int(level, level > 0) then
    error(('Level `%s` is not valid!'):format(vim.inspect(level)), ERROR)
  end
  if with_icon == nil then
    with_icon = true
  end

  if vim.tbl_isempty(M.levels) then
    return ''
  end

  local values = {} ---@type integer[]
  for k in pairs(M.levels) do
    if level - k <= 0 then
      table.insert(values, k)
    end
  end

  local l = math.min(unpack(values))
  if l then
    return with_icon and ('%s %s'):format(M.levels[l].icon, M.levels[l].title) or M.levels[l].title
  end

  return ''
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
