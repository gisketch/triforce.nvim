---@module 'triforce.types'

local ERROR = vim.log.levels.ERROR
local Util = require('triforce.util')

---@class Triforce.Achievements
local M = {}

local unique_languages = 0 ---@type integer

local achievements = { ---@type Achievement[]
  {
    id = 'first_100',
    name = 'First Steps',
    desc = 'Type 100 characters',
    icon = '🌱',
    check = function(stats)
      return stats.chars_typed >= 100
    end,
  },
  {
    id = 'first_1000',
    name = 'Getting Started',
    desc = 'Type 1,000 characters',
    icon = '⚔️',
    check = function(stats)
      return stats.chars_typed >= 1000
    end,
  },
  {
    id = 'first_10000',
    name = 'Dedicated Coder',
    desc = 'Type 10,000 characters',
    icon = '🛡️',
    check = function(stats)
      return stats.chars_typed >= 10000
    end,
  },
  {
    id = 'first_100000',
    name = 'Master Scribe',
    desc = 'Type 100,000 characters',
    icon = '📜',
    check = function(stats)
      return stats.chars_typed >= 100000
    end,
  },
  {
    id = 'level_5',
    name = 'Rising Star',
    desc = 'Reach level 5',
    icon = '⭐',
    check = function(stats)
      return stats.level >= 5
    end,
  },
  {
    id = 'level_10',
    name = 'Expert Coder',
    desc = 'Reach level 10',
    icon = '💎',
    check = function(stats)
      return stats.level >= 10
    end,
  },
  {
    id = 'level_25',
    name = 'Champion',
    desc = 'Reach level 25',
    icon = '👑',
    check = function(stats)
      return stats.level >= 25
    end,
  },
  {
    id = 'level_50',
    name = 'Legend',
    desc = 'Reach level 50',
    icon = '🔱',
    check = function(stats)
      return stats.level >= 50
    end,
  },
  {
    id = 'sessions_10',
    name = 'Regular Visitor',
    desc = 'Complete 10 sessions',
    icon = '🔄',
    check = function(stats)
      return stats.sessions >= 10
    end,
  },
  {
    id = 'sessions_50',
    name = 'Creature of Habit',
    desc = 'Complete 50 sessions',
    icon = '📅',
    check = function(stats)
      return stats.sessions >= 50
    end,
  },
  {
    id = 'sessions_100',
    name = 'Dedicated Hero',
    desc = 'Complete 100 sessions',
    icon = '🏆',
    check = function(stats)
      return stats.sessions >= 100
    end,
  },
  {
    id = 'time_1h',
    name = 'First Hour',
    desc = 'Code for 1 hour total',
    icon = '⏰',
    check = function(stats)
      return stats.time_coding >= 3600
    end,
  },
  {
    id = 'time_10h',
    name = 'Committed',
    desc = 'Code for 10 hours total',
    icon = '⌛',
    check = function(stats)
      return stats.time_coding >= 36000
    end,
  },
  {
    id = 'time_100h',
    name = 'Veteran',
    desc = 'Code for 100 hours total',
    icon = '🕐',
    check = function(stats)
      return stats.time_coding >= 360000
    end,
  },
  {
    id = 'polyglot_3',
    name = 'Polyglot Beginner',
    desc = 'Code in 3 different languages',
    icon = '🌍',
    check = function()
      return unique_languages >= 3
    end,
  },
  {
    id = 'polyglot_5',
    name = 'Polyglot',
    desc = 'Code in 5 different languages',
    icon = '🌎',
    check = function()
      return unique_languages >= 5
    end,
  },
  {
    id = 'polyglot_10',
    name = 'Master Polyglot',
    desc = 'Code in 10 different languages',
    icon = '🌏',
    check = function()
      return unique_languages >= 10
    end,
  },
  {
    id = 'polyglot_15',
    name = 'Language Virtuoso',
    desc = 'Code in 15 different languages',
    icon = '🗺️',
    check = function()
      return unique_languages >= 15
    end,
  },
}

---Get all achievements with their unlock status.
--- ---
---@param stats Stats
---@return Achievement[] achievements
function M.get_all_achievements(stats)
  Util.validate({ stats = { stats, { 'table' } } })

  -- Count unique languages
  unique_languages = 0
  for _ in pairs(stats.chars_by_language or {}) do
    unique_languages = unique_languages + 1
  end
  return achievements
end

---@param achievement Achievement[]|Achievement
---@param stats Stats
function M.new_achievements(achievement, stats)
  Util.validate({
    achievement = { achievement, { 'table' } },
    stats = { stats, { 'table' } },
  })
  if vim.tbl_isempty(achievement) then
    return
  end

  if not Util.is_dict(achievement) then
    ---@cast achievement Achievement[]
    for _, achv in ipairs(achievement) do
      M.new_achievements(achv, stats)
    end
    return
  end

  ---@cast achievement Achievement
  Util.validate({
    ['achievement.id'] = { achievement.id, { 'string' } },
    ['achievement.check'] = { achievement.check, { 'function' } },
    ['achievement.name'] = { achievement.name, { 'string' } },
    ['achievement.desc'] = { achievement.desc, { 'string', 'nil' }, true },
    ['achievement.icon'] = { achievement.icon, { 'string', 'nil' }, true },
  })

  if vim.list_contains({ achievement.id, achievement.name }, '') then
    vim.notify('Either new achievement ID or name are empty!', ERROR)
    return
  end

  achievement.desc = achievement.desc or 'No Description'
  achievement.icon = achievement.icon or ''

  local new = true ---@type boolean
  for i, achv in ipairs(achievements) do
    if achv.id == achievement.id then
      achievements[i] = achievement
      new = false
      break
    end
  end
  if new then
    table.insert(achievements, achievement)
  end

  M.check_achievements(stats)
end

---Check and unlock achievements
---@param stats Stats
---@return Achievement[] newly_unlocked List of achievement objects.
function M.check_achievements(stats)
  Util.validate({ stats = { stats, { 'table' } } })

  local newly_unlocked = {} ---@type Achievement[]
  for _, achievement in ipairs(M.get_all_achievements(stats)) do
    if achievement.check(stats) and not stats.achievements[achievement.id] then
      stats.achievements[achievement.id] = true
      table.insert(newly_unlocked, {
        id = achievement.id,
        check = achievement.check,
        name = achievement.name,
        desc = achievement.desc or '',
        icon = achievement.icon or '',
      })
    end
  end
  return newly_unlocked
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
