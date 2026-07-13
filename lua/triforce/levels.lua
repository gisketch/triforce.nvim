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
local M = {}

local levels = {} ---@type LevelTitles

---@param override? boolean
function M.setup(override)
  Util.validate({ override = { override, { 'boolean', 'nil' }, true } })
  if override == nil then
    override = false
  end

  if not override then
    levels = vim.tbl_deep_extend('keep', levels, get_default_titles())
  end
end

---@param lvls LevelParams[]|LevelParams
function M.add_levels(lvls)
  Util.validate({ lvls = { lvls, { 'table' } } })
  if vim.tbl_isempty(lvls) then
    return
  end

  if vim.islist(lvls) then
    ---@cast lvls LevelParams[]
    for _, lvl in ipairs(lvls) do
      M.add_levels(lvl)
    end
    return
  end

  ---@cast lvls LevelParams
  Util.validate({
    lvls_level = { lvls.level, { 'number' } },
    lvls_title = { lvls.title, { 'string' } },
    lvls_icon = { lvls.icon, { 'string', 'nil' }, true },
  })

  levels[lvls.level] = { title = lvls.title, icon = lvls.icon or '' }
end

---@param stats Stats
---@return LevelSpec[] all_levels
function M.get_all_levels(stats)
  Util.validate({ stats = { stats, { 'table' } } })

  local keys = vim.tbl_keys(levels) --[[@as integer[]\]]
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

  if vim.tbl_isempty(levels) then
    return ''
  end

  local values = {} ---@type integer[]
  for k in pairs(levels) do
    if level - k <= 0 then
      table.insert(values, k)
    end
  end
  return levels[math.min(unpack(values))].icon or '💫'
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

  if vim.tbl_isempty(levels) then
    return ''
  end

  local values = {} ---@type integer[]
  for k in pairs(levels) do
    if level - k <= 0 then
      table.insert(values, k)
    end
  end

  local l = math.min(unpack(values))
  if l then
    return with_icon and ('%s %s'):format(levels[l].icon, levels[l].title) or levels[l].title
  end

  return ''
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
