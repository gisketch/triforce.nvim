---@class TriforceLangData
---@field lang string
---@field count integer

---Profile UI using Volt
local volt = require('volt')
local voltui = require('volt.ui')
local voltstate = require('volt.state') ---@type table<integer, { h: integer }>

local stats_module = require('triforce.stats')
local achievement_module = require('triforce.achievement')
local tracker = require('triforce.tracker')
local languages = require('triforce.languages')
local random_stats = require('triforce.random_stats')
local util = require('triforce.util')

---@class Triforce.Ui.Profile
local Profile = {
  -- UI state
  buf = nil, ---@type integer|nil
  win = nil, ---@type integer|nil
  dim_win = nil, ---@type integer|nil
  dim_buf = nil, ---@type integer|nil
  ns = vim.api.nvim_create_namespace('TriforceProfile'), ---@type integer
  achievements_page = 1, ---@type integer
  achievements_per_page = 5, ---@type integer
  max_language_entries = 13, ---@type integer
  current_tab = ' Stats', ---@type string

  -- Dimensions
  width = 80, ---@type integer
  height = 30, ---@type integer
  xpad = 2, ---@type integer
}

-- Set up keybindings
function Profile.close()
  if Profile.win and vim.api.nvim_win_is_valid(Profile.win) then
    vim.api.nvim_win_close(Profile.win, true)
  end
  if Profile.dim_win and vim.api.nvim_win_is_valid(Profile.dim_win) then
    vim.api.nvim_win_close(Profile.dim_win, true)
  end
  if Profile.buf and vim.api.nvim_buf_is_valid(Profile.buf) then
    vim.api.nvim_buf_delete(Profile.buf, { force = true })
  end
  if Profile.dim_buf and vim.api.nvim_buf_is_valid(Profile.dim_buf) then
    vim.api.nvim_buf_delete(Profile.dim_buf, { force = true })
  end
  Profile.buf = nil
  Profile.win = nil
  Profile.dim_win = nil
  Profile.dim_buf = nil
end

-- Helper function to redraw achievements tab
function Profile.redraw_achievements()
  if Profile.current_tab ~= '󰌌 Achievements' then
    return
  end

  vim.bo[Profile.buf].modifiable = true
  volt.gen_data({
    { buf = Profile.buf, layout = Profile.get_layout(), xpad = Profile.xpad, ns = Profile.ns },
  })

  local new_height = voltstate[Profile.buf].h
  local current_lines = vim.api.nvim_buf_line_count(Profile.buf)

  if current_lines < new_height then
    local empty_lines = {}
    for _ = 1, (new_height - current_lines) do
      table.insert(empty_lines, '')
    end
    vim.api.nvim_buf_set_lines(Profile.buf, current_lines, current_lines, false, empty_lines)
  elseif current_lines > new_height then
    vim.api.nvim_buf_set_lines(Profile.buf, new_height, current_lines, false, {})
  end

  volt.redraw(Profile.buf, 'all')
  vim.bo[Profile.buf].modifiable = false
end

---Get Zelda-themed title based on level
---@param level integer
---@return string title
function Profile.get_level_title(level)
  util.validate({ level = { level, { 'number' } } })

  local titles = {
    { max = 10, title = 'Deku Scrub', icon = '🌱' },
    { max = 20, title = 'Kokiri', icon = '🌳' },
    { max = 30, title = 'Hylian Soldier', icon = '🗡️' },
    { max = 40, title = 'Knight', icon = '⚔️' },
    { max = 50, title = 'Royal Guard', icon = '🛡️' },
    { max = 60, title = 'Master Swordsman', icon = '⚡' },
    { max = 70, title = 'Hero of Time', icon = '🔺' },
    { max = 80, title = 'Sage', icon = '✨' },
    { max = 90, title = 'Triforce Bearer', icon = '🔱' },
    { max = 100, title = 'Champion', icon = '👑' },
    { max = 120, title = 'Divine Beast Pilot', icon = '🦅' },
    { max = 150, title = 'Ancient Hero', icon = '🏛️' },
    { max = 180, title = 'Legendary Warrior', icon = '⚜️' },
    { max = 200, title = 'Goddess Chosen', icon = '🌟' },
    { max = 250, title = 'Demise Slayer', icon = '💀' },
    { max = 300, title = 'Eternal Legend', icon = '💫' },
  }

  for _, tier in ipairs(titles) do
    if level <= tier.max then
      return ('%s %s'):format(tier.icon, tier.title)
    end
  end

  return '💫 Eternal Legend' -- Max title for level > 300
end

---Get activity level highlight based on lines typed
---@param lines integer
---@return 'LineNr'|'TriforceHeat0'|'TriforceHeat1'|'TriforceHeat2'|'TriforceHeat3' hl
function Profile.get_activity_hl(lines)
  if lines == 0 then
    return 'LineNr'
  end
  if lines <= 50 then
    return 'TriforceHeat3' -- Lightest
  end
  if lines <= 150 then
    return 'TriforceHeat2' -- Light-medium
  end
  if lines <= 300 then
    return 'TriforceHeat1' -- Medium-bright
  end

  return 'TriforceHeat0' -- Brightest
end

local BASE_DAYS_IN_MONTHS = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

local function is_leap_year(y)
  return (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0)
end

local function days_in_month(month, y)
  if month ~= 2 then
    return BASE_DAYS_IN_MONTHS[month]
  end
  return is_leap_year(y) and 29 or 28
end

---Build activity heatmap (copied from typr structure)
---@param stats Stats
---@return table lines
function Profile.build_activity_heatmap(stats)
  if not stats or not stats.daily_activity then
    return { { { '  No activity data yet', 'Comment' } } }
  end

  local year = os.date('%Y')
  local current_month = tonumber(os.date('%m'))

  local months = { 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' }
  local days = { 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat' }

  local months_to_show = 7
  local squares_len = months_to_show * 4

  -- Build an explicit wrapped sequence of the last 7 months ending at current month
  local current_year_num = tonumber(year)
  local month_seq = {}
  for offset = months_to_show - 1, 0, -1 do
    local m = current_month - offset
    local y = current_year_num
    while m < 1 do
      m = m + 12
      y = y - 1
    end
    table.insert(month_seq, { month = m, year = y })
  end

  -- Build lines structure (typr style)
  local lines = {
    { { '   ', 'TriforceGreen' }, { '  ' } },
    {},
  }

  -- Month headers
  for idx, my in ipairs(month_seq) do
    local month_idx = my.month
    table.insert(lines[1], { '  ' .. months[month_idx] .. '  ', 'TriforceRed' })
    table.insert(lines[1], { idx == #month_seq and '' or '  ' })
  end

  -- Separator line
  local hrline = voltui.separator('─', squares_len * 2 + (months_to_show - 1 + 5), 'Comment')
  table.insert(lines[2], hrline[1])

  -- Day labels
  for day = 1, 7 do
    local line = { { days[day], 'Comment' }, { ' │ ', 'Comment' } }
    table.insert(lines, line)
  end

  -- Fill in activity data
  for idx, my in ipairs(month_seq) do
    local month_idx = my.month
    local month_year = tostring(my.year)

    local start_day = util.getday_i(1, month_idx, my.year)

    -- Empty cells before month starts (only for first month)
    if idx == 1 and start_day ~= 1 then
      for n = 1, start_day - 1 do
        table.insert(lines[n + 2], { '  ' })
      end
    end

    -- Activity squares for each day
    for day_num = 1, days_in_month(month_idx, my.year) do
      local day_of_week = util.getday_i(day_num, month_idx, my.year)
      local date_key = ('%s-%s-%s'):format(month_year, util.double_digits(month_idx), util.double_digits(day_num))

      local activity = stats.daily_activity[date_key] or 0
      local hl = Profile.get_activity_hl(activity)

      table.insert(lines[day_of_week + 2], { '󱓻 ', hl })
    end
  end

  -- Add border (typr style)
  voltui.border(lines)

  -- Header with legend (typr style)
  local header = {
    { ' 󰃭 Activity' },
    { '_pad_' },
    { '    Less ' },
  }

  local hlgroups = { 'LineNr', 'TriforceHeat4', 'TriforceHeat3', 'TriforceHeat2', 'TriforceHeat1' }

  for _, hl in ipairs(hlgroups) do
    table.insert(header, { '󱓻 ', hl })
  end

  table.insert(header, { ' More' })
  table.insert(lines, 1, voltui.hpad(header, Profile.width - (2 * Profile.xpad) - 4))

  return lines
end

---Get streak with proper calculation
---@param stats Stats
---@return integer current
function Profile.get_current_streak(stats)
  -- Recalculate to ensure accuracy
  local current = stats_module.calculate_streaks(stats)
  return current
end

---Build Stats tab content
---@return table
function Profile.build_stats_tab()
  local stats = tracker.get_stats()
  if not stats then
    return { { { 'No stats available', 'Comment' } } }
  end

  local streak = Profile.get_current_streak(stats)
  local level_title = Profile.get_level_title(stats.level)
  local xp_current = stats.xp
  local xp_next = stats_module.xp_for_next_level(stats.level)
  local xp_prev = stats.level > 1 and stats_module.xp_for_next_level(stats.level - 1) or 0
  local xp_progress = ((xp_current - xp_prev) / (xp_next - xp_prev)) * 100

  -- Get random fact
  local random_fact = random_stats.get_random_fact(stats)

  -- Compact fact display with streak integration
  local fact_section = {
    {
      { ' ' .. random_fact .. '.', 'Normal' },
    },
    {},
  }

  -- Three progress bars section
  local barlen = (Profile.width - Profile.xpad * 2) / 3 - 1

  -- Dynamic session goal (increments by 100)
  local session_goal = math.ceil(stats.sessions / 100) * 100
  session_goal = session_goal == stats.sessions and (session_goal + 100) or session_goal
  local session_progress = (stats.sessions / session_goal) * 100

  -- Dynamic time goal (10h -> 25h -> 50h -> 100h -> 200h -> 300h...)
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

  -- 1. Level progress
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

  -- 2. Session milestone progress
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

  -- 3. Time goal progress
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
    { lines = level_stats, w = barlen, pad = 2 },
    { lines = session_stats, w = barlen, pad = 2 },
    { lines = time_stats, w = barlen },
  })

  -- Stats table
  local stats_table = {
    {
      ' Sessions',
      ' Characters',
      ' Lines',
      ' Time',
      ' Streak',
    },
    {
      tostring(stats.sessions),
      tostring(stats.chars_typed),
      tostring(stats.lines_typed),
      util.format_time(stats.time_coding),
      streak > 0 and (tostring(streak) .. ' day' .. (streak > 1 and 's' or '')) or '0',
    },
  }

  local table_ui = voltui.table(stats_table, Profile.width - Profile.xpad * 2, 'String')

  -- Activity heatmap
  local heatmap_lines = Profile.build_activity_heatmap(stats)
  local heatmap_row = voltui.grid_col({
    { lines = {}, w = 1 },
    { lines = heatmap_lines, w = Profile.width - Profile.xpad * 2 },
  })

  -- Footer
  local footer = {
    {},
    {},
    { { '  <Tab>: Switch Tabs | <S-Tab>: Switch Tabs Backwards | q: Close', 'Comment' } },
    {},
  }

  return voltui.grid_row({
    fact_section,
    progress_section,
    { {} },
    table_ui,
    { {} },
    heatmap_row,
    -- heatmap_lines,
    footer,
  })
end

---Build Achievements tab content
---@return table
function Profile.build_achievements_tab()
  local stats = tracker.get_stats()
  if not stats then
    return { { { 'No stats available', 'PmenuSel' } } }
  end

  local achievements = achievement_module.get_all_achievements(stats)

  -- Sort: unlocked first
  table.sort(achievements, function(a, b)
    return a.check(stats) == b.check(stats) and (a.name < b.name) or (a.check(stats) and not b.check(stats))
  end)

  -- Calculate pagination
  local total_achievements = #achievements
  local total_pages = math.ceil(total_achievements / Profile.achievements_per_page)

  -- Ensure current page is within bounds
  if Profile.achievements_page > total_pages then
    Profile.achievements_page = total_pages
  end
  if Profile.achievements_page < 1 then
    Profile.achievements_page = 1
  end

  -- Get achievements for current page
  local start_idx = (Profile.achievements_page - 1) * Profile.achievements_per_page + 1
  local end_idx = math.min(start_idx + Profile.achievements_per_page - 1, total_achievements)

  -- Build table rows with virtual text for custom highlighting
  -- Each cell with custom hl must be an array of {text, hl} pairs
  local table_data = {
    { 'Status', 'Achievement', 'Description' }, -- Header (plain strings)
  }

  for i = start_idx, end_idx do
    local achievement = achievements[i]
    local status_icon = achievement.check(stats) and '✓' or '✗'
    local status_hl = achievement.check(stats) and 'String' or 'Comment'
    local text_hl = achievement.check(stats) and 'TriforceYellow' or 'Comment'
    local desc_hl = achievement.check(stats) and 'Normal' or 'Comment'

    -- Only show icon if unlocked
    local name_display = achievement.check(stats) and (achievement.icon .. ' ' .. achievement.name) or achievement.name

    table.insert(table_data, {
      { { status_icon, status_hl } }, -- Array of virt text chunks
      { { name_display, text_hl } },
      { { achievement.desc, desc_hl } },
    })
  end

  local achievement_table = voltui.table(table_data, Profile.width - Profile.xpad * 2, 'String')

  local unlocked_count = 0
  for _, a in ipairs(achievements) do
    if a.check(stats) then
      unlocked_count = unlocked_count + 1
    end
  end

  -- Compact achievement info
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

  -- Footer with pagination info
  local footer = {
    {},
    {},
    {
      { '  <Tab>: Switch Tabs | <S-Tab>: Switch Tabs Backwards | q: Close', 'Comment' },
    },
    {
      { '  H/L or ◀/▶: ', 'Comment' },
      { ('Page %s/%s'):format(Profile.achievements_page, total_pages), 'String' },
    },
  }

  return voltui.grid_row({
    achievement_info,
    achievement_table,
    footer,
  })
end

---Build Languages tab content
---@return table
function Profile.build_languages_tab()
  local stats = tracker.get_stats()
  if not stats then
    return { { { 'No stats available', 'Comment' } } }
  end

  -- Get language data and sort by character count
  local lang_data = {} ---@type TriforceLangData[]
  for lang, count in pairs(stats.chars_by_language or {}) do
    if not languages.is_excluded(lang) then
      table.insert(lang_data, { lang = lang, count = count })
    end
  end

  table.sort(lang_data, function(a, b)
    return a.count > b.count
  end)

  -- Limit to max entries
  local display_count = math.min(#lang_data, Profile.max_language_entries)

  -- Prepare data for bar graph
  local graph_values = {}
  local max_chars = 0

  -- Get max for scaling
  for i = 1, display_count do
    if lang_data[i].count > max_chars then
      max_chars = lang_data[i].count
    end
  end

  -- Fill graph values (scale to 100)
  for i = 1, Profile.max_language_entries do
    table.insert(
      graph_values,
      (i <= display_count and (max_chars > 0 and math.floor((lang_data[i].count / max_chars) * 100) or 0) or 0)
    )
  end

  -- -- Create labels with icons
  -- local labels = {}
  -- for i = 1, Profile.max_language_entries do
  --   if i <= display_count then
  --     local icon = languages.get_icon(lang_data[i].lang)
  --     labels[i] = icon ~= '' and icon or lang_data[i].lang:sub(1, 1)
  --   else
  --     labels[i] = '·' -- Empty slot
  --   end
  -- end

  -- Calculate graph width (narrower for centering)
  local graph_width = math.min(Profile.max_language_entries * 4, Profile.width - Profile.xpad * 2)
  local graph_data = {
    val = graph_values,
    -- footer_label = { " Character count by language" },
    format_labels = function(x)
      return max_chars == 0 and '0' or tostring(math.floor((x * max_chars / 100)))
    end,
    baropts = {
      w = 3,
      gap = 2,
      hl = 'TriforceYellow',
    },
  }

  local graph_lines = voltui.graphs.bar(graph_data)

  -- Center the graph by calculating left padding
  local left_pad = 2

  -- Centered graph section
  local centered_graph = voltui.grid_col({
    { lines = { {} }, w = left_pad }, -- Left spacing
    { lines = graph_lines, w = graph_width },
  })

  -- Footer
  local footer = {
    {},
    {},
    { { '  <Tab>: Switch Tabs Forwards | <S-Tab>: Switch Tabs Backwards | q: Close', 'Comment' } },
    {},
  }

  -- Calculate dynamic spacing based on max label width
  local max_label_length = tostring(max_chars):len()
  local x_axis_spacing = 6 + max_label_length
  local spacing_str = (' '):rep(x_axis_spacing)
  local graph_x_axis_parts = { { spacing_str } }
  for i = 1, math.min(Profile.max_language_entries, #lang_data) do
    local icon = languages.get_icon(lang_data[i].lang)
    local hl = 'Comment'
    if icon then
      table.insert(graph_x_axis_parts, { icon ~= '' and icon or '', icon ~= '' and hl or 'Comment' })
      if i < math.min(Profile.max_language_entries, #lang_data) then
        table.insert(graph_x_axis_parts, { (' '):rep(4) }) -- 4 spaces between icons
      end
    end
  end

  local graph_x_axis = { graph_x_axis_parts }

  if display_count == 0 then
    graph_x_axis = {
      {},
      { { ('%sNo language data yet. Start coding!'):format((' '):rep(2)), 'Comment' } },
    }
  end

  -- Language summary info
  local language_info, summary_parts = { {} }, {}
  local pre_msgs = { ' You code primarily in ', ', with ', ' and ' }
  local hls = { 'TriforceRed', 'TriforceBlue', 'TriforcePurple' }
  local i, added = 1, 1
  if display_count > 0 then
    local display_name
    while display_count >= i and added <= 3 do
      display_name = languages.get_display_name(lang_data[i].lang)
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

  return voltui.grid_row({
    language_info,
    centered_graph,
    graph_x_axis,
    footer,
  })
end

---Set up custom highlights
function Profile.setup_highlights()
  local get_hl = require('volt.utils').get_hl
  local config = require('triforce.config')

  -- Get base colors
  local normal_bg = get_hl('Normal').bg

  -- Set custom highlights for Triforce (linked to standard highlights)
  if normal_bg then
    vim.api.nvim_set_hl(Profile.ns, 'TriforceNormal', { bg = normal_bg })
    vim.api.nvim_set_hl(Profile.ns, 'TriforceBorder', { link = 'String' })
  else
    normal_bg = '#000000' -- Fallback for transparent backgrounds
  end

  -- Create Triforce highlight groups - change these to customize colors
  local hls = { ---@type table<string, vim.api.keyset.highlight>
    TriforceRed = { link = 'Keyword' },
    TriforceGreen = { link = 'String' },
    TriforceYellow = { link = 'Question' },
    TriforceBlue = { link = 'Identifier' },
    TriforcePurple = { link = 'Number' },
  }
  for group, hl in pairs(hls) do
    vim.api.nvim_set_hl(Profile.ns, group, hl)
  end

  -- Heat levels: index maps to highlight group number and mix percentage
  local heat_levels = {
    { name = 0, mix_pct = 0 },
    { name = 1, mix_pct = 20 },
    { name = 2, mix_pct = 50 },
    { name = 3, mix_pct = 65 },
    { name = 4, mix_pct = 80 },
  }

  local heat_hls = (config.config and config.config.heat_highlights)
    or (config.defaults and config.defaults().heat_highlights)
    or {}
  for _, level in ipairs(heat_levels) do
    local hl = ('TriforceHeat%d'):format(level.name)
    local fg = heat_hls[hl]

    -- If fg is a group name (string without leading '#'), link to that group.
    -- Otherwise treat it as a color (hex string, number, etc.) and set fg.
    if fg then
      local key = (type(fg) == 'string' and fg:sub(1, 1) ~= '#') and 'link' or 'fg'
      vim.api.nvim_set_hl(Profile.ns, hl, { [key] = fg })
    end
  end
  -- Link to standard highlights
  vim.api.nvim_set_hl(Profile.ns, 'FloatBorder', { link = 'TriforceBorder' })
  vim.api.nvim_set_hl(Profile.ns, 'Normal', { link = 'TriforceNormal' })
end

---Get layout for tab system
---@return table
function Profile.get_layout()
  local components = {
    [' Stats'] = Profile.build_stats_tab,
    ['󰌌 Achievements'] = Profile.build_achievements_tab,
    ['0 Languages'] = Profile.build_languages_tab,
  }

  return {
    {
      lines = function()
        return { {} }
      end,
      name = 'top-separator',
    },
    {
      lines = function()
        return voltui.tabs(
          { ' Stats', '󰌌 Achievements', '0 Languages' },
          Profile.width - Profile.xpad * 2,
          { active = Profile.current_tab }
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
        return components[Profile.current_tab]()
      end,
      name = 'content',
    },
  }
end

---@param back? boolean
function Profile.cycle_tab(back)
  util.validate({ back = { back, { 'boolean', 'nil' }, true } })
  back = back ~= nil and back or false

  local tabs = { ' Stats', '󰌌 Achievements', '0 Languages' }
  local pos = 1
  for i, tab in ipairs(tabs) do
    if tab == Profile.current_tab then
      pos = i
      break
    end
  end

  -- Cycle through tabs
  pos = util.cycle_range(pos, 1, #tabs, back)
  Profile.current_tab = tabs[pos]

  -- Make buffer modifiable
  vim.bo[Profile.buf].modifiable = true

  -- Reinitialize layout with new content
  volt.gen_data({
    { buf = Profile.buf, layout = Profile.get_layout(), xpad = Profile.xpad, ns = Profile.ns },
  })

  -- Get new height and ensure buffer has enough lines
  local new_height = voltstate[Profile.buf].h
  local current_lines = vim.api.nvim_buf_line_count(Profile.buf)

  -- Add more lines if needed
  if current_lines < new_height then
    local empty_lines = {}
    for _ = 1, (new_height - current_lines) do
      table.insert(empty_lines, '')
    end
    vim.api.nvim_buf_set_lines(Profile.buf, current_lines, current_lines, false, empty_lines)
  elseif current_lines > new_height then
    -- Remove extra lines if buffer is too big
    vim.api.nvim_buf_set_lines(Profile.buf, new_height, current_lines, false, {})
  end

  -- Update window height if needed
  if new_height ~= Profile.height then
    Profile.height = new_height
    vim.api.nvim_win_set_config(Profile.win, {
      row = math.floor((vim.o.lines - Profile.height) / 2),
      col = math.floor((vim.o.columns - Profile.width) / 2),
      width = Profile.width,
      height = Profile.height,
      relative = 'editor',
      border = 'none',
    })
  end

  -- Redraw content
  volt.redraw(Profile.buf, 'all')
  vim.bo[Profile.buf].modifiable = false
end

---Open profile window
function Profile.open()
  if Profile.buf and vim.api.nvim_buf_is_valid(Profile.buf) then
    return
  end

  -- Create buffer
  Profile.buf = vim.api.nvim_create_buf(false, true)

  -- Create dimmed background
  Profile.dim_buf = vim.api.nvim_create_buf(false, true)
  Profile.dim_win = vim.api.nvim_open_win(Profile.dim_buf, false, {
    focusable = false,
    row = 0,
    col = 0,
    width = vim.o.columns,
    height = vim.o.lines - 2,
    relative = 'editor',
    style = 'minimal',
    border = 'none',
  })
  vim.wo[Profile.dim_win].winblend = 20

  -- Initialize Volt
  volt.gen_data({
    { buf = Profile.buf, layout = Profile.get_layout(), xpad = Profile.xpad, ns = Profile.ns },
  })

  Profile.height = voltstate[Profile.buf].h

  -- Window config
  local row = math.floor((vim.o.lines - Profile.height) / 2)
  local col = math.floor((vim.o.columns - Profile.width) / 2)

  Profile.win = vim.api.nvim_open_win(Profile.buf, true, {
    row = row,
    col = col,
    width = Profile.width,
    height = Profile.height,
    relative = 'editor',
    style = 'minimal',
    border = 'none',
    zindex = 100,
  })

  -- Apply highlights
  Profile.setup_highlights()
  vim.api.nvim_win_set_hl_ns(Profile.win, Profile.ns)

  -- Run Volt to render content
  volt.run(Profile.buf, { h = Profile.height, w = Profile.width - Profile.xpad * 2 })

  -- Use Volt's built-in mapping system
  volt.mappings({
    bufs = { Profile.buf, Profile.dim_buf },
    winclosed_event = true,
    after_close = Profile.close,
  })

  -- Tab switching
  vim.keymap.set('n', '<Tab>', Profile.cycle_tab, { buffer = Profile.buf, noremap = true, silent = true })
  vim.keymap.set('n', '<S-Tab>', function()
    Profile.cycle_tab(true)
  end, { buffer = Profile.buf, noremap = true, silent = true })

  -- Pagination keymaps for achievements
  local pagination_keys = { 'h', 'H', '<Left>', 'l', 'L', '<Right>' }
  for _, key in ipairs(pagination_keys) do
    vim.keymap.set('n', key, function()
      if Profile.current_tab ~= '󰌌 Achievements' then
        return
      end

      if vim.list_contains({ 'h', 'H', '<Left>' }, key) then
        if Profile.achievements_page > 1 then
          Profile.achievements_page = Profile.achievements_page - 1
          Profile.redraw_achievements()
        end
      elseif vim.list_contains({ 'l', 'L', '<Right>' }, key) then
        local stats = tracker.get_stats()
        if stats then
          local achievements = achievement_module.get_all_achievements(stats)
          local total_pages = math.ceil(#achievements / Profile.achievements_per_page)
          if Profile.achievements_page < total_pages then
            Profile.achievements_page = Profile.achievements_page + 1
            Profile.redraw_achievements()
          end
        end
      end
    end, { buffer = Profile.buf })
  end

  -- Set filetype
  vim.bo[Profile.buf].filetype = 'triforce-profile'
end

return Profile
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
