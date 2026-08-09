---@class TriforceLangData
---@field count integer
---@field lang string

---@class Triforce.UIDimensions
---@field dim_float? { buf: integer, win: integer }|nil|?
---@field float? { buf: integer, win: integer }|nil|?
---@field height integer
---@field width integer
---@field xpad integer

---@class Triforce.Ui.Profile.TabsMap
---@field stats 1
---@field achievements 2
---@field languages 3
---@field levels 4
---@field items 5

---@alias Triforce.Ui.Profile.TabIndeces 1|2|3|4|5
---@alias PaginationKey 'H'|'L'|'<Left>'|'<Right>'|'h'|'l'

local MONTHS = { 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' }
local DAYS = { 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat' }

local volt = require('volt')
local voltui = require('volt.ui')
local Util = require('triforce.util')

local ns = vim.api.nvim_create_namespace('TriforceProfile')

local items_per_page = 5 ---@type integer
local achievements_per_page = 5 ---@type integer
local achievements_page = 1 ---@type integer
local max_language_entries = 13 ---@type integer
local levels_per_page = 5 ---@type integer
local items_page = 1 ---@type integer
local levels_page = 1 ---@type integer
local current_tab = 1 ---@type Triforce.Ui.Profile.TabIndeces
local dimensions = { ---@type Triforce.UIDimensions
  width = math.floor(vim.o.columns * 0.76),
  height = math.floor(vim.o.lines * 0.9),
  xpad = 2,
}

local all_tabs = { ---@type string[]
  '1   Stats',
  '2  󰌌 Achievements',
  '3   Languages',
  '4  󱡁 Levels',
  '5  Items',
}
local tabs_map = { ---@type Triforce.Ui.Profile.TabsMap
  stats = 1,
  achievements = 2,
  languages = 3,
  levels = 4,
  items = 5,
}

---@class Triforce.Ui.Profile
local Profile = {}

---@return Triforce.Ui.Profile.TabsMap tabs_map
function Profile.get_tabs_map()
  return tabs_map
end

---@return Triforce.UIDimensions dimensions
function Profile.get_dimensions()
  return dimensions
end

---@return Triforce.Ui.Profile.TabIndeces current_tab
function Profile.get_current_tab()
  return current_tab
end

---Close up profile window
function Profile.close()
  local backdrop = require('triforce.config').get().backdrop
  if not (dimensions.float or (backdrop and backdrop.enabled and dimensions.dim_float)) then
    return
  end

  if backdrop and backdrop.enabled then
    pcall(vim.api.nvim_buf_delete, dimensions.dim_float.buf, { force = true })
    pcall(vim.api.nvim_win_close, dimensions.dim_float.win, true)
    dimensions.dim_float = nil
  end

  pcall(vim.api.nvim_win_close, dimensions.float.win, true)
  pcall(vim.api.nvim_buf_delete, dimensions.float.buf, { force = true })

  dimensions.float = nil
end

---Toggle profile window
---@param tab? integer
function Profile.toggle(tab)
  Util.validate({ tab = { tab, { 'number', 'nil' }, true } })
  tab = tab or nil

  local Config = require('triforce.config')
  if not (dimensions.float and (Config.get().backdrop.enabled and dimensions.dim_float)) then
    Profile.open(tab)
    return
  end

  Profile.close()
end

---@param key PaginationKey
---@return function paginator
function Profile.pagination_fun(key)
  Util.validate({ key = { key, { 'string' } } })

  return function()
    if not vim.tbl_contains({ 2, 4 }, current_tab) then
      return
    end

    if current_tab == 2 then
      if vim.list_contains({ 'h', 'H', '<Left>' }, key) and achievements_page > 1 then
        achievements_page = achievements_page - 1
        Profile.redraw()
      elseif vim.list_contains({ 'l', 'L', '<Right>' }, key) then
        local stats = require('triforce.tracker').get_stats()
        if stats then
          local achievements = require('triforce.achievement').get_all_achievements(stats)
          if achievements_page < math.ceil(#achievements / achievements_per_page) then
            achievements_page = achievements_page + 1
            Profile.redraw()
          end
        end
      end

      return
    end

    if vim.list_contains({ 'h', 'H', '<Left>' }, key) then
      if levels_page > 1 then
        levels_page = levels_page - 1
        Profile.redraw()
      end
    elseif vim.list_contains({ 'l', 'L', '<Right>' }, key) then
      local stats = require('triforce.tracker').get_stats()
      if stats and levels_page < math.ceil(#(require('triforce.levels').get_all_levels(stats)) / levels_per_page) then
        levels_page = levels_page + 1
        Profile.redraw()
      end
    end
  end
end

---Helper function to redraw either the achievements or levels tabs
function Profile.redraw()
  if not ((dimensions.float and dimensions.float.buf) and vim.list_contains({ 2, 4 }, current_tab)) then
    return
  end

  vim.api.nvim_set_option_value('modifiable', true, { buf = dimensions.float.buf })
  volt.gen_data({
    {
      buf = dimensions.float.buf,
      layout = Profile.get_layout(),
      xpad = dimensions.xpad,
      ns = ns,
    },
  })

  local new_height = require('volt.state')[dimensions.float.buf].h
  local current_lines = vim.api.nvim_buf_line_count(dimensions.float.buf)
  if current_lines < new_height then
    local empty_lines = {}
    for _ = 1, (new_height - current_lines) do
      table.insert(empty_lines, '')
    end
    vim.api.nvim_buf_set_lines(dimensions.float.buf, current_lines, current_lines, false, empty_lines)
  elseif current_lines > new_height then
    vim.api.nvim_buf_set_lines(dimensions.float.buf, new_height, current_lines, false, {})
  end

  volt.redraw(dimensions.float.buf, 'all')
  vim.api.nvim_set_option_value('modifiable', false, { buf = dimensions.float.buf })
end

---Get activity level highlight based on lines typed
---@param lines integer
---@return 'TriforceHeat0'|'TriforceHeat1'|'TriforceHeat2'|'TriforceHeat3'|'TriforceHeat4' hl
function Profile.get_activity_hl(lines)
  if lines == 0 then
    return 'TriforceHeat4' -- Lightest
  end
  if lines <= 50 then
    return 'TriforceHeat3' -- Light
  end
  if lines <= 150 then
    return 'TriforceHeat2' -- Light-medium
  end
  if lines <= 300 then
    return 'TriforceHeat1' -- Medium-bright
  end

  return 'TriforceHeat0' -- Brightest
end

---Build activity heatmap (copied from typr structure)
---@param stats Stats
---@return string[][][]|string[][] lines
function Profile.build_activity_heatmap(stats)
  if not stats or not stats.daily_activity then
    return { { { '  No activity data yet', 'Comment' } } }
  end

  local year = os.date('%Y')
  local current_month = tonumber(os.date('%m'), 10)
  local months_to_show = 9
  local squares_len = months_to_show * 4
  local current_year_num = tonumber(year, 10)
  local month_seq = {} ---@type { month: integer, year: integer }[]
  for offset = months_to_show - 1, 0, -1 do
    local m = current_month - offset
    local y = current_year_num
    while m < 1 do
      m = m + 12
      y = y - 1
    end
    table.insert(month_seq, { month = m, year = y })
  end

  local lines = { ---@type string[][][]|string[][]
    { { '   ', 'TriforceGreen' }, { '  ' } },
    {},
  }

  for idx, my in ipairs(month_seq) do
    local month_idx = my.month
    table.insert(lines[1], { '  ' .. MONTHS[month_idx] .. '  ', 'TriforceRed' })
    table.insert(lines[1], { idx == #month_seq and '' or '  ' })
  end

  local hrline = voltui.separator('-', squares_len * 2 + (months_to_show - 1 + 5), 'Comment')
  table.insert(lines[2], hrline[1])

  for day = 1, 7 do
    local line = { { DAYS[day], 'Comment' }, { ' │ ', 'Comment' } }
    table.insert(lines, line)
  end

  for idx, my in ipairs(month_seq) do
    local month_idx = my.month
    local month_year = tostring(my.year)
    local start_day = Util.getday_i(1, month_idx, my.year)

    if idx == 1 and start_day ~= 1 then
      for n = 1, start_day - 1 do
        table.insert(lines[n + 2], { '  ' })
      end
    end

    for day_num = 1, Util.days_in_month(month_idx, my.year) do
      local day_of_week = Util.getday_i(day_num, month_idx, my.year)
      local date_key = ('%s-%s-%s'):format(month_year, Util.double_digits(month_idx), Util.double_digits(day_num))
      table.insert(lines[day_of_week + 2], { '󱓻 ', Profile.get_activity_hl(stats.daily_activity[date_key] or 0) })
    end
  end

  voltui.border(lines)

  local header = { ---@type string[][][]|string[][]
    { ' 󰃭 Activity' },
    { '_pad_' },
    { 'Less ' },
    { ' More' },
  }

  for _, hl in ipairs({ 'TriforceHeat4', 'TriforceHeat3', 'TriforceHeat2', 'TriforceHeat1', 'TriforceHeat0' }) do
    table.insert(header, #header, { '󱓻 ', hl })
  end

  table.insert(lines, 1, voltui.hpad(header, dimensions.width - (2 * dimensions.xpad) - 4))

  return lines
end

---Build Stats tab content
---@return string[][][]|string[][] lines
function Profile.build_stats_tab()
  local stats_module = require('triforce.stats')
  local stats = require('triforce.tracker').get_stats()
  if not stats then
    return { { { 'No stats available', 'Comment' } } }
  end

  local streak = stats_module.get_current_streak(stats)
  local xp_prev = stats.level > 1 and stats_module.xp_for_next_level(stats.level - 1) or 0
  local xp_progress = ((stats.xp - xp_prev) * 100) / (stats_module.xp_for_next_level(stats.level) - xp_prev)
  local fact_section = {
    { { ' ' .. require('triforce.random_stats').get_random_fact(stats) .. '.', 'TriforceRed' } },
    {},
  }

  local barlen = math.floor((dimensions.width - dimensions.xpad * 2) / 3) - 1
  local session_goal = math.ceil(stats.sessions / 100) * 100
  session_goal = session_goal == stats.sessions and (session_goal + 100) or session_goal
  local session_progress = (stats.sessions / session_goal) * 100

  local current_hours = stats.time_coding / 3600
  local time_goal_hours
  if current_hours < 10 then
    time_goal_hours = 10
  elseif current_hours < 25 then
    time_goal_hours = 25
  elseif current_hours < 50 then
    time_goal_hours = 50
  elseif current_hours < 100 then
    time_goal_hours = 100
  else
    time_goal_hours = math.ceil(current_hours / 100) * 100
    if time_goal_hours == current_hours then
      time_goal_hours = time_goal_hours + 100
    end
  end
  local time_goal = time_goal_hours * 3600
  local time_progress = (stats.time_coding / time_goal) * 100
  local level_stats = {
    { { ' 󰓏', 'TriforceYellow' }, { ' Level ~ ' }, { tostring(stats.level), 'TriforceYellow' } },
    {},
    voltui.progressbar({
      w = barlen,
      val = xp_progress > 100 and 100 or xp_progress,
      icon = { on = '┃', off = '┃' },
      hl = { on = 'TriforceYellow', off = 'Comment' },
    }),
  }
  local session_stats = {
    {
      { '󰪺', 'TriforceRed' },
      { ' Sessions ~ ' },
      { tostring(stats.sessions) .. ' / ' .. tostring(session_goal), 'TriforceRed' },
    },
    {},
    voltui.progressbar({
      w = barlen,
      val = session_progress > 100 and 100 or session_progress,
      icon = { on = '┃', off = '┃' },
      hl = { on = 'TriforceRed', off = 'Comment' },
    }),
  }
  local time_stats = {
    {
      { '󱑈', 'TriforceBlue' },
      { ' Time ~ ' },
      { ('%sh / %sh'):format(math.floor(current_hours), time_goal_hours), 'TriforceBlue' },
    },
    {},
    voltui.progressbar({
      w = barlen,
      val = time_progress > 100 and 100 or time_progress,
      icon = { on = '┃', off = '┃' },
      hl = { on = 'TriforceBlue', off = 'Comment' },
    }),
  }
  local progress_section = voltui.grid_col({
    { lines = level_stats, w = barlen, pad = dimensions.xpad },
    { lines = session_stats, w = barlen, pad = dimensions.xpad },
    { lines = time_stats, w = barlen },
  })
  local stats_table_1 = {
    { ' Time', ' Sessions', ' Streak' },
    {
      Util.format_time(stats.time_coding),
      tostring(stats.sessions),
      streak > 0 and (tostring(streak) .. ' day' .. (streak > 1 and 's' or '')) or '0',
    },
  }
  local stats_table_2 = {
    { ' Characters', ' Lines', ' Currency' },
    { tostring(stats.chars_typed), tostring(stats.lines_typed), tostring(stats.currency) },
  }
  local table_ui_1 = voltui.table(stats_table_1, dimensions.width - dimensions.xpad * 2, 'Function')
  local table_ui_2 = voltui.table(stats_table_2, dimensions.width - dimensions.xpad * 2, 'Number')
  local heatmap_row = voltui.grid_col({
    { lines = {}, w = 1 },
    { lines = Profile.build_activity_heatmap(stats), w = dimensions.width - dimensions.xpad * 2 },
  })
  local footer = {
    {},
    {},
    {
      { '  ', 'Comment' },
      { '<Tab>', 'TriforceGreen' },
      { ': Switch Tabs | ', 'Comment' },
      { '<S-Tab>', 'TriforceGreen' },
      { ': Switch Tabs Backwards | ', 'Comment' },
      { 'q', 'TriforceGreen' },
      { ': Close', 'Comment' },
    },
    {},
  }

  return voltui.grid_row({
    fact_section,
    progress_section,
    { {} },
    table_ui_1,
    table_ui_2,
    { {} },
    heatmap_row,
    footer,
  })
end

---@return string[][][]|string[][] lines
function Profile.build_items_tab()
  local items = require('triforce.items').get_items()
  local stats = require('triforce.tracker').get_stats()
  if vim.tbl_isempty(items) or not stats then
    return { { { 'No items available', 'Comment' } } }
  end

  local all_items = vim.tbl_values(items)
  table.sort(all_items, function(a, b)
    local a_avail, b_avail = a:available(stats, true), b:available(stats, true)
    return a_avail and b_avail and (a.name < b.name) or (a_avail and not b_avail)
  end)
  local total_items = #all_items
  local total_pages = math.ceil(total_items / items_per_page)
  if items_page > total_pages then
    items_page = total_pages
  end
  if items_page < 1 then
    items_page = 1
  end

  local start_idx = (items_page - 1) * items_per_page + 1
  local end_idx = math.min(start_idx + items_per_page - 1, total_items)
  local table_data = { { 'Price', 'Item', 'Available' } }
  for i = start_idx, end_idx do
    local item = all_items[i]
    local checked = item:available(stats, true)
    table.insert(table_data, {
      { { tostring(item:price(stats)), checked and 'Number' or 'Comment' } },
      { { item.name, checked and 'TriforceYellow' or 'Comment' } },
      { { checked and '✓' or '✗', checked and 'Normal' or 'Comment' } },
    })
  end

  local item_table = voltui.table(table_data, dimensions.width - dimensions.xpad * 2, 'String')
  local avail_count = 0
  for _, a in pairs(items) do
    if a:available(stats, true) then
      avail_count = avail_count + 1
    end
  end

  local item_info = {
    {
      { ' Current Currency: ', 'Identifier' },
      { tostring(stats.currency), 'Number' },
    },
    {},
  }
  local footer = {
    {},
    {},
    {
      { '  ', 'Comment' },
      { '<Tab>', 'TriforceGreen' },
      { ': Switch Tabs | ', 'Comment' },
      { '<S-Tab>', 'TriforceGreen' },
      { ': Switch Tabs Backwards | ', 'Comment' },
      { 'q', 'TriforceGreen' },
      { ': Close', 'Comment' },
    },
    {
      { '  ', 'Comment' },
      { 'H', 'TriforceGreen' },
      { '/', 'Comment' },
      { 'L', 'TriforceGreen' },
      { 'or ', 'Comment' },
      { '◀', 'TriforceGreen' },
      { '/', 'Comment' },
      { '▶', 'TriforceGreen' },
      { ': ', 'Comment' },
      { ('Page %s/%s'):format(items_page, total_pages), 'Number' },
    },
  }

  return voltui.grid_row({
    item_info,
    item_table,
    footer,
  })
end

---Build Achievements tab content
---@return string[][][]|string[][] lines
function Profile.build_achievements_tab()
  local stats = require('triforce.tracker').get_stats()
  if not stats then
    return { { { 'No stats available!', 'PmenuSel' } } }
  end

  local achievements = require('triforce.achievement').get_all_achievements(stats)

  -- Sort: unlocked first
  table.sort(achievements, function(a, b)
    local a_unlocked, b_unlocked = a.check(stats), b.check(stats)
    return a_unlocked == b_unlocked and (a.name < b.name) or (a_unlocked and not b_unlocked)
  end)

  local total_achievements = #achievements
  local total_pages = math.ceil(total_achievements / achievements_per_page)
  if achievements_page > total_pages then
    achievements_page = total_pages
  end
  if achievements_page < 1 then
    achievements_page = 1
  end

  local start_idx = (achievements_page - 1) * achievements_per_page + 1
  local end_idx = math.min(start_idx + achievements_per_page - 1, total_achievements)
  local table_data = { { 'Status', 'Achievement', 'Description' } }
  for i = start_idx, end_idx do
    local achievement = achievements[i]
    local checked = achievement.check(stats)
    local status_icon = checked and '✓' or '✗'
    local status_hl = checked and 'String' or 'Comment'
    local text_hl = checked and 'TriforceYellow' or 'Comment'
    local desc_hl = checked and 'Normal' or 'Comment'
    local name_display = checked and (achievement.icon .. ' ' .. achievement.name) or achievement.name
    table.insert(table_data, {
      { { status_icon, status_hl } },
      { { name_display, text_hl } },
      { { achievement.desc, desc_hl } },
    })
  end

  local achievement_table = voltui.table(table_data, dimensions.width - dimensions.xpad * 2, 'String')
  local unlocked_count = 0
  for _, a in ipairs(achievements) do
    if a.check(stats) then
      unlocked_count = unlocked_count + 1
    end
  end

  local achievement_info = {
    {
      { ' Hey, listen!', 'Identifier' },
      { " You've unlocked " },
      { tostring(unlocked_count), 'String' },
      { ' out of ' },
      { tostring(#achievements), 'Number' },
      { ' achievements!' },
    },
    {},
  }
  local footer = {
    {},
    {},
    {
      { '  ', 'Comment' },
      { '<Tab>', 'TriforceGreen' },
      { ': Switch Tabs | ', 'Comment' },
      { '<S-Tab>', 'TriforceGreen' },
      { ': Switch Tabs Backwards | ', 'Comment' },
      { 'q', 'TriforceGreen' },
      { ': Close', 'Comment' },
    },
    {
      { '  ', 'Comment' },
      { 'H', 'TriforceGreen' },
      { '/', 'Comment' },
      { 'L', 'TriforceGreen' },
      { 'or ', 'Comment' },
      { '◀', 'TriforceGreen' },
      { '/', 'Comment' },
      { '▶', 'TriforceGreen' },
      { ': ', 'Comment' },
      { ('Page %s/%s'):format(achievements_page, total_pages), 'Number' },
    },
  }

  return voltui.grid_row({
    achievement_info,
    achievement_table,
    footer,
  })
end

---Build levels tab content
---@return string[][][]|string[][] lines
function Profile.build_levels_tab()
  local stats = require('triforce.tracker').get_stats()
  if not stats then
    return { { { 'No stats available!', 'PmenuSel' } } }
  end

  local levels = require('triforce.levels').get_all_levels(stats)

  -- Sort: unlocked first
  table.sort(levels, function(a, b)
    return a.unlocked == b.unlocked and (a.level < b.level) or (a.unlocked and not b.unlocked)
  end)

  local total_levels = #levels
  local total_pages = math.ceil(total_levels / levels_per_page)
  if levels_page > total_pages then
    levels_page = total_pages
  end
  if levels_page < 1 then
    levels_page = 1
  end

  local start_idx = (levels_page - 1) * levels_per_page + 1
  local end_idx = math.min(start_idx + levels_per_page - 1, total_levels)

  local table_data = { ---@type string[][][]|string[][]
    { 'Unlocked', 'Level', 'Title' },
  }

  for i = start_idx, end_idx do
    local level = levels[i]
    local unlocked_icon = level.unlocked and '✓' or '✗'
    local unlocked_hl = level.unlocked and 'String' or 'Comment'
    local text_hl = level.unlocked and 'TriforceYellow' or 'Comment'
    local desc_hl = level.unlocked and 'Normal' or 'Comment'
    local name_display = ('%s'):format(level.level)
    table.insert(table_data, {
      { { unlocked_icon, unlocked_hl } },
      { { name_display, text_hl } },
      { { level.title, desc_hl } },
    })
  end

  local levels_table = voltui.table(table_data, dimensions.width - dimensions.xpad * 2, 'String')
  local unlocked_count = 0
  for _, a in ipairs(levels) do
    if a.unlocked then
      unlocked_count = unlocked_count + 1
    end
  end

  local levels_info = { ---@type string[][][]|string[][]
    {
      { 'Current level: ' },
      { ('%d'):format(stats.level), 'Number' },
    },
    {},
  }
  local footer = { ---@type string[][][]|string[][]
    {},
    {
      { '  ' },
      { '<Tab>', 'TriforceGreen' },
      { ': Switch Tabs | ', 'Comment' },
      { '<S-Tab>', 'TriforceGreen' },
      { ': Switch Tabs Backwards | ', 'Comment' },
      { 'q', 'TriforceGreen' },
      { ': Close |', 'Comment' },
    },
    {
      { '  ' },
      { 'H', 'TriforceGreen' },
      { '/', 'Comment' },
      { 'L', 'TriforceGreen' },
      { ' or ', 'Comment' },
      { '◀', 'TriforceGreen' },
      { '/', 'Comment' },
      { '▶', 'TriforceGreen' },
      { ': ', 'Comment' },
      { ('Page %s/%s'):format(levels_page, total_pages), 'Number' },
    },
  }

  return voltui.grid_row({
    levels_info,
    levels_table,
    footer,
  })
end

---Build Languages tab content
---@return string[][][]|string[][] lines
function Profile.build_languages_tab()
  local stats = require('triforce.tracker').get_stats()
  if not stats then
    return { { { 'No stats available', 'Comment' } } }
  end

  local lang_data = {} ---@type TriforceLangData[]
  for lang, count in pairs(stats.chars_by_language or {}) do
    if not require('triforce.languages').is_excluded(lang) then
      table.insert(lang_data, { lang = lang, count = count })
    end
  end

  table.sort(lang_data, function(a, b)
    return a.count > b.count
  end)

  local display_count = math.min(#lang_data, max_language_entries)
  local graph_values = {}
  local max_chars = 0
  for i = 1, display_count do
    if lang_data[i].count > max_chars then
      max_chars = lang_data[i].count
    end
  end

  for i = 1, max_language_entries do
    table.insert(
      graph_values,
      (i <= display_count and (max_chars > 0 and math.floor((lang_data[i].count / max_chars) * 100) or 0) or 0)
    )
  end

  local graph_width = math.min(max_language_entries * 4, dimensions.width - dimensions.xpad * 2)
  local graph_data = {
    val = graph_values,
    footer_label = { ' Character count by language' },
    format_labels = function(x)
      return max_chars == 0 and '0' or tostring(math.floor((x * max_chars / 100)))
    end,
    baropts = { w = 3, gap = 2, hl = 'TriforceYellow' },
  }
  local graph_lines = voltui.graphs.bar(graph_data)
  local left_pad = 2
  local centered_graph = voltui.grid_col({
    { lines = { {} }, w = left_pad },
    { lines = graph_lines, w = graph_width },
  })
  local footer = {
    {},
    {},
    {
      { '  ', 'Comment' },
      { '<Tab>', 'TriforceGreen' },
      { ': Switch Tabs Forwards | ', 'Comment' },
      { '<S-Tab>', 'TriforceGreen' },
      { ': Switch Tabs Backwards | ', 'Comment' },
      { 'q', 'TriforceGreen' },
      { ': Close', 'Comment' },
    },
    {},
  }
  local max_label_length = tostring(max_chars):len()
  local x_axis_spacing = 6 + max_label_length
  local spacing_str = (' '):rep(x_axis_spacing)
  local graph_x_axis_parts = { { spacing_str } }
  for i = 1, math.min(max_language_entries, #lang_data) do
    local icon = require('triforce.languages').get_icon(lang_data[i].lang)
    if icon then
      local hl = icon ~= '' and 'TriforceHeat0' or 'Comment'
      table.insert(graph_x_axis_parts, { icon, hl })
      if i < math.min(max_language_entries, #lang_data) then
        table.insert(graph_x_axis_parts, { (' '):rep(4) }) -- 4 spaces between icons
      end
    end
  end

  local graph_x_axis = { graph_x_axis_parts }
  if display_count == 0 then
    graph_x_axis = { {}, { { ('%sNo language data yet. Start coding!'):format((' '):rep(2)), 'Comment' } } }
  end

  local language_info, summary_parts = { {} }, {}
  local pre_msgs = { ' You code primarily in ', ', with ', ' and ' }
  local hls = { 'TriforceRed', 'TriforceBlue', 'TriforcePurple' }
  local i, added = 1, 1
  if display_count > 0 then
    while display_count >= i and added <= 3 do
      local display_name = require('triforce.languages').get_display_name(lang_data[i].lang)
      if display_name then
        if added <= #pre_msgs then
          table.insert(summary_parts, { pre_msgs[added] })
        end
        table.insert(summary_parts, { display_name, hls[added] })
        added = added + 1
      end

      i = i + 1
    end

    if display_count >= 2 then
      table.insert(summary_parts, { ' close behind', 'Normal' })
    end

    language_info = { summary_parts, {} }
  end

  return voltui.grid_row({ language_info, centered_graph, graph_x_axis, footer })
end

---Set up custom highlights
function Profile.setup_highlights()
  local config = require('triforce.config')
  local normal_bg = require('volt.utils').get_hl('Normal').bg
  if normal_bg then
    vim.api.nvim_set_hl(ns, 'TriforceNormal', { bg = normal_bg })
    vim.api.nvim_set_hl(ns, 'TriforceBorder', { link = 'String' })
  else
    normal_bg = '#000000' -- Fallback for transparent backgrounds
  end

  local hls = { ---@type table<string, vim.api.keyset.highlight>
    TriforceRed = { link = 'Keyword' },
    TriforceGreen = { link = 'String' },
    TriforceYellow = { link = 'Question' },
    TriforceBlue = { link = 'Identifier' },
    TriforcePurple = { link = 'Number' },
  }
  for group, hl in pairs(hls) do
    vim.api.nvim_set_hl(ns, group, hl)
  end

  -- Heat levels: index maps to highlight group number and mix percentage
  local heat_levels = {
    { name = 0, mix_pct = 0 },
    { name = 1, mix_pct = 20 },
    { name = 2, mix_pct = 50 },
    { name = 3, mix_pct = 65 },
    { name = 4, mix_pct = 80 },
  }
  local heat_hls = config.get().heat_highlights or config.defaults().heat_highlights
  for _, level in ipairs(heat_levels) do
    local hl = ('TriforceHeat%d'):format(level.name)
    local fg = heat_hls[hl] ---@type string|nil|?
    if fg then
      local key = (Util.is_type('string', fg) and fg:sub(1, 1) ~= '#') and 'link' or 'fg'
      vim.api.nvim_set_hl(ns, hl, { [key] = fg })
    end
  end
  vim.api.nvim_set_hl(ns, 'FloatBorder', { link = 'TriforceBorder' })
  vim.api.nvim_set_hl(ns, 'Normal', { link = 'TriforceNormal' })
end

---Get layout for tab system
---@return VoltData.Layout[] layout
function Profile.get_layout()
  local components = { ---@type table<string, fun(): (string[][][]|string[][])>
    Profile.build_stats_tab,
    Profile.build_achievements_tab,
    Profile.build_languages_tab,
    Profile.build_levels_tab,
    Profile.build_items_tab,
  }
  return { ---@type VoltData.Layout[]
    {
      lines = function()
        return { {} }
      end,
      name = 'top-separator',
    },
    {
      lines = function()
        return voltui.tabs(
          all_tabs,
          dimensions.width - dimensions.xpad * 2,
          { active = all_tabs[current_tab], hlon = 'pmenusel', hloff = 'pmenu' }
        )
      end,
      name = 'tabs',
    },
    {
      lines = function()
        return { {} }
      end,
      name = 'separator',
    },
    {
      lines = function()
        return components[current_tab]()
      end,
      name = 'content',
    },
  }
end

---@param back? boolean
---@param num? Triforce.Ui.Profile.TabIndeces
function Profile.cycle_tab(back, num)
  Util.validate({
    back = { back, { 'boolean', 'nil' }, true },
    num = { num, { 'number', 'nil' }, true },
  })
  back = back ~= nil and back or false
  num = (num and Util.is_int(num)) and num or 0

  local old_tab = current_tab
  local positions = vim.tbl_keys(all_tabs) --[[@as integer[]\]]
  local pos = 1 ---@type Triforce.Ui.Profile.TabIndeces
  if not vim.list_contains(positions, num) then
    for i, _ in ipairs(all_tabs) do
      if i == current_tab then
        pos = i
        break
      end
    end
    pos = Util.cycle_range(pos, 1, #all_tabs, back)
    current_tab = pos
  else
    current_tab = num
  end

  vim.api.nvim_set_option_value('modifiable', true, { buf = dimensions.float.buf })
  volt.gen_data({
    {
      buf = dimensions.float.buf,
      layout = Profile.get_layout(),
      xpad = dimensions.xpad,
      ns = ns,
    },
  })

  local new_height = require('volt.state')[dimensions.float.buf].h
  local current_lines = vim.api.nvim_buf_line_count(dimensions.float.buf)
  if current_lines < new_height then
    local empty_lines = {}
    for _ = 1, (new_height - current_lines) do
      table.insert(empty_lines, '')
    end
    vim.api.nvim_buf_set_lines(dimensions.float.buf, current_lines, current_lines, false, empty_lines)
  elseif current_lines > new_height then
    vim.api.nvim_buf_set_lines(dimensions.float.buf, new_height, current_lines, false, {})
  end

  if new_height ~= dimensions.height then
    vim.api.nvim_win_set_config(dimensions.float.win, {
      row = math.floor((vim.o.lines - new_height) / 2),
      col = math.floor((vim.o.columns - dimensions.width) / 2),
      width = dimensions.width,
      height = new_height,
      relative = 'editor',
      border = 'none',
    })
    dimensions.height = new_height
  end

  volt.redraw(dimensions.float.buf, 'all')
  vim.api.nvim_set_option_value('modifiable', false, { buf = dimensions.float.buf })
  vim.api.nvim_win_set_cursor(dimensions.float.win, { 1, 0 })

  for _, key in ipairs({ 'h', 'H', '<Left>', 'l', 'L', '<Right>' }) do
    if vim.list_contains({ 2, 4, 5 }, old_tab) and not vim.list_contains({ 2, 4, 5 }, current_tab) then
      vim.keymap.del('n', key, { buffer = dimensions.float.buf })
    elseif vim.list_contains({ 2, 4, 5 }, current_tab) then
      vim.keymap.set('n', key, Profile.pagination_fun(key), { buffer = dimensions.float.buf })
    end
  end
end

---Open profile window
---@param tab? Triforce.Ui.Profile.TabIndeces
function Profile.open(tab)
  Util.validate({ tab = { tab, { 'number', 'nil' }, true } })
  tab = (tab and vim.tbl_contains(tabs_map, tab)) and tab or current_tab
  if dimensions.float and vim.api.nvim_buf_is_valid(dimensions.float.buf) then
    return
  end

  local backdrop = require('triforce.config').get().backdrop

  current_tab = tab

  dimensions.float = {}
  dimensions.float.buf = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_set_option_value('filetype', 'triforce-profile', { buf = dimensions.float.buf })

  if backdrop and backdrop.enabled then
    dimensions.dim_float = {}
    dimensions.dim_float.buf = vim.api.nvim_create_buf(false, true)
    dimensions.dim_float.win = vim.api.nvim_open_win(dimensions.dim_float.buf, false, {
      focusable = false,
      row = 1,
      col = 0,
      width = vim.o.columns,
      height = vim.o.lines - 2,
      relative = 'editor',
      style = 'minimal',
      border = 'none',
    })

    vim.api.nvim_set_option_value('winblend', backdrop.winblend or 20, { win = dimensions.dim_float.win })
  end

  volt.gen_data({
    {
      buf = dimensions.float.buf,
      layout = Profile.get_layout(),
      xpad = dimensions.xpad,
      ns = ns,
    },
  })

  dimensions.height = require('volt.state')[dimensions.float.buf].h
  dimensions.float.win = vim.api.nvim_open_win(dimensions.float.buf, true, {
    row = math.floor((vim.o.lines - dimensions.height) / 2),
    col = math.floor((vim.o.columns - dimensions.width) / 2),
    width = dimensions.width,
    height = dimensions.height,
    relative = 'editor',
    style = 'minimal',
    border = 'none',
    zindex = 50,
  })

  Profile.setup_highlights()
  vim.api.nvim_win_set_hl_ns(dimensions.float.win, ns)
  vim.api.nvim_win_set_cursor(dimensions.float.win, { 1, 0 })

  volt.run(dimensions.float.buf, { h = dimensions.height, w = dimensions.width - dimensions.xpad * 2 })
  volt.mappings({
    bufs = { dimensions.float.buf, backdrop.enabled and dimensions.dim_float.buf or nil },
    winclosed_event = true,
    after_close = Profile.close,
  })

  vim.keymap.set('n', '<Tab>', Profile.cycle_tab, { buffer = dimensions.float.buf })
  vim.keymap.set('n', '<S-Tab>', function()
    Profile.cycle_tab(true)
  end, { buffer = dimensions.float.buf })

  for i = 1, #all_tabs, 1 do
    vim.keymap.set('n', ('%s'):format(i), function()
      Profile.cycle_tab(nil, i)
    end, { buffer = dimensions.float.buf })
  end

  if vim.list_contains({ 2, 4 }, current_tab) then
    for _, key in ipairs({ 'h', 'H', '<Left>', 'l', 'L', '<Right>' }) do
      vim.keymap.set('n', key, Profile.pagination_fun(key), { buffer = dimensions.float.buf })
    end
  end
end

return Profile
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
