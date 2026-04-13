local Util = require('triforce.util')

---Random stat generator for displaying varied coding facts
---@class Triforce.RandomStats
local RandStats = {}

---Generate a random stat fact based on current stats
---@param stats Stats
---@return string fact
function RandStats.get_random_fact(stats)
  Util.validate({ stats = { stats, { 'table' } } })

  local facts = {} ---@type string[]

  -- Calculate derived metrics
  local total_hours = math.floor(stats.time_coding / 3600)
  local total_minutes = math.floor(stats.time_coding / 60)
  local avg_session_time = stats.sessions > 0 and math.floor(stats.time_coding / stats.sessions / 60) or 0
  local chars_per_line = stats.lines_typed > 0 and math.floor(stats.chars_typed / stats.lines_typed) or 0
  local unique_languages = 0
  for _ in pairs(stats.chars_by_language or {}) do
    unique_languages = unique_languages + 1
  end

  -- Get most used language
  local top_lang, top_count = nil, 0
  for lang, count in pairs(stats.chars_by_language or {}) do
    if count > top_count then
      top_count = count
      top_lang = lang
    end
  end

  -- Character-based facts
  if stats.chars_typed > 0 then
    table.insert(facts, ("You've typed %s characters"):format(RandStats.format_number(stats.chars_typed)))

    if stats.chars_typed >= 1000 then
      local pages = math.floor(stats.chars_typed / 3000)
      table.insert(facts, ("That's about %d pages of text"):format(pages))
    end

    if stats.chars_typed >= 100000 then
      local novels = math.floor(stats.chars_typed / 300000)
      table.insert(facts, ("You've written the equivalent of `%d` novel%s"):format(novels, novels > 1 and 's' or ''))
    end

    if stats.chars_typed >= 10000 then
      local words = math.floor(stats.chars_typed / 5)
      table.insert(facts, ('Approximately %s words typed'):format(RandStats.format_number(words)))
    end
  end

  -- Line-based facts
  if stats.lines_typed > 0 then
    table.insert(facts, ("You've written `%s` lines of code"):format(RandStats.format_number(stats.lines_typed)))

    if stats.lines_typed >= 1000 then
      table.insert(facts, ("That's `%d` screens of code"):format(math.floor(stats.lines_typed / 50)))
    end

    if chars_per_line > 0 then
      table.insert(facts, ('Average line length: `%d` characters'):format(chars_per_line))
    end
  end

  -- Time-based facts
  if total_hours > 0 then
    table.insert(facts, ("You've coded for `%d` hours total"):format(total_hours))

    if total_hours >= 100 then
      local days = math.floor(total_hours / 24)
      table.insert(facts, ("That's `%d` full days of coding"):format(days))
    end

    if total_hours >= 1000 then
      table.insert(facts, "You're well on your way to 10,000 hours of mastery")
    end
  end

  if total_minutes > 0 and stats.sessions > 0 then
    table.insert(facts, ('Average session: %d minutes'):format(avg_session_time))
  end

  -- Session-based facts
  if stats.sessions > 0 then
    table.insert(facts, ("You've started %d coding sessions"):format(stats.sessions))

    if stats.sessions >= 100 then
      table.insert(facts, 'Consistency is key - keep it up')
    end
  end

  -- Language-based facts
  if unique_languages > 0 then
    table.insert(
      facts,
      ('You code in `%d` different language%s'):format(unique_languages, unique_languages > 1 and 's' or '')
    )

    if top_lang then
      table.insert(facts, ('%s is your favorite language'):format(RandStats.format_language_name(top_lang)))
    end

    if unique_languages >= 5 then
      table.insert(facts, "You're a true polyglot developer")
    end

    if unique_languages >= 10 then
      table.insert(facts, "You've become a master of programming languages")
    end
  end

  if stats.level > 1 then
    table.insert(facts, ("You're level `%d` with %s XP"):format(stats.level, RandStats.format_number(stats.xp)))

    if stats.level >= 10 then
      table.insert(facts, "You've reached expert territory")
    end

    if stats.level >= 25 then
      table.insert(facts, "You're among the elite coders")
    end

    if stats.level >= 50 then
      table.insert(facts, 'Legendary status achieved')
    end
  end

  -- Streak-based facts
  if stats.current_streak > 0 then
    table.insert(
      facts,
      ('Current streak: `%d` day%s'):format(stats.current_streak, stats.current_streak > 1 and 's' or '')
    )

    if stats.current_streak >= 7 then
      table.insert(facts, 'A full week of coding - great dedication')
    end

    if stats.current_streak >= 30 then
      table.insert(facts, "30 day streak - you're unstoppable")
    end
  end

  if stats.longest_streak > 0 and stats.longest_streak > stats.current_streak then
    table.insert(facts, ('Longest streak: `%d` days'):format(stats.longest_streak))
  end

  -- Fun comparative facts
  if stats.chars_typed >= 100000 then
    table.insert(facts, "You've typed more than the entire US Constitution")
  end

  if stats.time_coding >= 86400 then
    table.insert(facts, "You've spent a full 24 hours in your editor")
  end

  -- Default fallback
  if vim.tbl_isempty(facts) then
    table.insert(facts, 'Start coding to see interesting stats')
  end

  -- Return random fact
  math.randomseed(os.time())
  return facts[math.random(#facts)]
end

---Format large numbers with commas
---@param num number
---@return string str
function RandStats.format_number(num)
  Util.validate({ num = { num, { 'number' } } })

  local formatted = tostring(num)
  local k

  while true do
    formatted, k = formatted:gsub('^(-?%d+)(%d%d%d)', '%1,%2')
    if k == 0 then
      break
    end
  end

  return formatted
end

---Format language name for display
---@param filetype string
function RandStats.format_language_name(filetype)
  Util.validate({ filetype = { filetype, { 'string' } } })

  local language_names = {} ---@type table<string, string>
  for ft, spec in pairs(require('triforce.languages').langs) do
    language_names[ft] = spec.name
  end

  return language_names[filetype] or filetype
end

return RandStats
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
