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
local Levels = {}

Levels.levels = {}

function Levels.setup()
  Levels.levels = vim.tbl_deep_extend('keep', Levels.levels, get_default_titles())
end

---@param levels LevelParams[]|LevelParams
function Levels.add_levels(levels)
  Util.validate({ levels = { levels, { 'table' } } })
  if vim.tbl_isempty(levels) then
    return
  end

  ---@cast levels LevelParams[]
  if vim.islist(levels) then
    for _, lvl in ipairs(levels) do
      Levels.add_levels(lvl)
    end
    return
  end

  ---@cast levels LevelParams
  Util.validate({
    levels_level = { levels.level, { 'number' } },
    levels_title = { levels.title, { 'string' } },
    levels_icon = { levels.icon, { 'string', 'nil' }, true },
  })

  Levels.levels[levels.level] = { title = levels.title, icon = levels.icon or '' }
end

---@param stats Stats
---@return LevelSpec[] all_levels
function Levels.get_all_levels(stats)
  Util.validate({ stats = { stats, { 'table' } } })

  local keys = vim.tbl_keys(Levels.levels) --[[@as integer[]\]]
  local res = {} ---@type LevelSpec[]
  for _, lvl in ipairs(keys) do
    table.insert(res, {
      level = lvl,
      unlocked = lvl <= stats.level,
      title = Levels.get_level_title(lvl),
    })
  end
  return res
end

---Get title based on given level
---@param level integer
---@return string title
function Levels.get_level_title(level)
  Util.validate({ level = { level, { 'number' } } })
  if not Util.is_int(level, level > 0) then
    error(('Level `%s` is not valid!'):format(vim.inspect(level)), ERROR)
  end

  local res_title = ''
  local max_lvl
  for lvl, title in pairs(Levels.levels) do
    max_lvl = lvl
    if level == lvl then
      res_title = ('%s %s'):format(title.icon, title.title)
      break
    end
  end
  if res_title == '' and level >= max_lvl then
    res_title = '💫 Eternal Legend' -- Max title for level > 300
  end

  return res_title
end

return Levels
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
