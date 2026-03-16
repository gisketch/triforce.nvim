local lualine_require = require('lualine_require')
local highlight = require('lualine.highlight')
local triforce_lualine = require('triforce.lualine')

---@class LuaLine.Super
---@field private _reset_components function
---@field apply_highlights function
---@field apply_icon function
---@field apply_on_click function
---@field apply_padding function
---@field apply_section_separators function
---@field apply_separator function
---@field create_hl function
---@field create_option_highlights function
---@field draw function
---@field format_fn function
---@field format_hl function
---@field get_default_hl function
---@field init function
---@field set_on_click function
---@field set_separator function
---@field status string
---@field strip_separator function
---@field private super { extend: function,init: function, new: function }
---@field update_status function

---@class TriforceLualine.Achievements
---@field opts Triforce.LualineConfig.Achievements
---@field callback fun(opts: Triforce.LualineConfig.Achievements)

---@class TriforceLualine.Level
---@field opts Triforce.LualineConfig.Level
---@field callback fun(opts: Triforce.LualineConfig.Level)

---@class TriforceLualine.SessionTime
---@field opts Triforce.LualineConfig.SessionTime
---@field callback fun(opts: Triforce.LualineConfig.SessionTime)

---@class TriforceLualine.Streak
---@field opts Triforce.LualineConfig.Streak
---@field callback fun(opts: Triforce.LualineConfig.Streak)

-- local M = require('lualine_require').require('lualine.component'):extend()
---@class TriforceLualine
---@field options Triforce.LualineConfig
---@field achievements TriforceLualine.Achievements
---@field level TriforceLualine.Level
---@field session_time TriforceLualine.SessionTime
---@field streak TriforceLualine.Streak
---@field private __is_lualine_component boolean
---@field protected super LuaLine.Super
local M = lualine_require.require('lualine.component'):extend()

function M:init(opts)
  M.super:init(opts)

  self.options = vim.tbl_deep_extend('keep', self.options or {}, triforce_lualine.get_defaults(), {
    achievements = { enabled = false },
    level = { enabled = true },
    session_time = { enabled = false },
    streak = { enabled = false },
  })

  self.achievements = { opts = self.options.achievements, callback = triforce_lualine.achievements }
  self.level = { opts = self.options.level, callback = triforce_lualine.level }
  self.session_time = { opts = self.options.session_time, callback = triforce_lualine.session_time }
  self.streak = { opts = self.options.streak, callback = triforce_lualine.streak }

  local hl_info = vim.api.nvim_get_hl(0, { name = 'Character' })
  local fg = hl_info.fg or nil
  local bg = hl_info.bg or nil
  local color = { fg = fg and ('#%02x'):format(fg) or nil, bg = bg and ('#%02x'):format(bg) or nil }
  self.color_active_hl = highlight.create_component_highlight_group(color, 'triforce_active', self.options)
end

function M:update_status()
  if package.loaded['triforce'] == nil then
    return ''
  end

  ---@type (TriforceLualine.Achievements|TriforceLualine.Level|TriforceLualine.SessionTime|TriforceLualine.Streak)[]
  local ordered = {}
  for _, component in ipairs({ self.achievements, self.level, self.session_time, self.streak }) do
    if component.opts.enabled then
      table.insert(ordered, component)
    end
  end

  if vim.tbl_isempty(ordered) then
    return ''
  end

  local msg = ''
  for i, component in ipairs(ordered) do
    if component.opts.enabled then
      msg = ((i ~= #ordered) and '%s%s | ' or '%s%s'):format(msg, component.callback(component.opts))
    end
  end

  return msg
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
