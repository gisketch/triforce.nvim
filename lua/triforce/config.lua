---@module 'triforce.types'

local Util = require('triforce.util')

local defaults = { ---@type TriforceConfigDefaults
  achievements = {},
  auto_save_interval = 300,
  backdrop = { enabled = true, winblend = 20 },
  custom_languages = {},
  db_path = vim.fs.joinpath(vim.fn.stdpath('data'), 'triforce_stats.json'),
  debug = false,
  enabled = true,
  gamification_enabled = true,
  heat_highlights = {
    TriforceHeat0 = '#f0f0f0',
    TriforceHeat1 = '#f0f0a0',
    TriforceHeat2 = '#f0a0a0',
    TriforceHeat3 = '#a0a0a0',
    TriforceHeat4 = '#707070',
  },
  icon_engine = 'builtin',
  ignore_ft = {},
  keymap = { show_profile = '' },
  levels = {},
  level_progression = {
    tier_1 = { min_level = 1, max_level = 10, xp_per_level = 500 },
    tier_2 = { min_level = 11, max_level = 20, xp_per_level = 750 },
    tier_3 = { min_level = 21, max_level = 30, xp_per_level = 1250 },
    tier_4 = { min_level = 31, max_level = 40, xp_per_level = 2500 },
    tier_5 = { min_level = 41, max_level = 50, xp_per_level = 3750 },
    tier_6 = { min_level = 51, max_level = 75, xp_per_level = 5000 },
    tier_7 = { min_level = 76, max_level = 100, xp_per_level = 10000 },
    tier_8 = { min_level = 101, max_level = 150, xp_per_level = 12500 },
    tier_9 = { min_level = 151, max_level = 225, xp_per_level = 15000 },
    tier_10 = { min_level = 226, max_level = math.huge, xp_per_level = 25000 },
  },
  notifications = { enabled = true, level_up = true, achievements = true },
  override_levels = false,
  xp_rewards = { char = 1, line = 1, save = 10 },
}

---@class Triforce.Config
---Setup options.
--- ---
---@field config TriforceConfigDefaults
local M = {}

---@param silent? boolean
---@return boolean gamified
function M.has_gamification(silent)
  Util.validate({ silent = { silent, { 'boolean', 'nil' }, true } })
  if silent == nil then
    silent = false
  end

  if M.config.gamification_enabled ~= nil and M.config.gamification_enabled then
    return true
  end

  if not silent then
    vim.notify('Gamification is not enabled in config', vim.log.levels.WARN)
  end
  return false
end

---@return TriforceConfigDefaults defaults
function M.defaults()
  return defaults
end

---@param opts? TriforceConfig
function M.new_config(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  M.config = vim.tbl_deep_extend('keep', opts or {}, defaults)

  local keys = vim.tbl_keys(M.defaults()) --[[@as string[]\]]
  for k, _ in pairs(M.config) do
    ---@cast k string
    if not vim.list_contains(keys, k) then
      M.config[k] = nil
    end
  end

  if M.config.backdrop and M.config.backdrop.winblend then
    if M.config.backdrop.winblend >= 100 then
      M.config.backdrop.winblend = 100
    elseif M.config.backdrop.winblend <= 0 then
      M.config.backdrop.winblend = 0
    end
  end
end

---Setup the plugin with user configuration
--- ---
---@param opts? TriforceConfig User configuration options.
function M.setup(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  M.new_config(opts or {})

  if not M.config.enabled then
    return
  end

  local stats_module = require('triforce.stats')
  local langs_module = require('triforce.languages')

  -- Apply custom level progression to stats module
  if M.config.level_progression then
    stats_module.level_config = M.config.level_progression
    stats_module.calibrate_tiers()
  end

  -- Register custom languages if provided
  if M.config.custom_languages then
    langs_module.register_custom_languages(M.config.custom_languages)
  end

  if M.config.ignore_ft then
    langs_module.exclude_langs(M.config.ignore_ft)
  end

  M.config.icon_engine = (M.config.icon_engine and vim.list_contains({ 'builtin', 'mini' }, M.config.icon_engine))
      and M.config.icon_engine
    or 'builtin'

  -- Setup custom path if provided
  stats_module.db_path = M.config.db_path
end

function M.open_window()
  local bufnr = vim.api.nvim_create_buf(false, true)
  local conf_data = M.get_config() or ''
  if conf_data == '' then
    return
  end

  vim.api.nvim_buf_set_lines(
    bufnr,
    0,
    -1,
    true,
    vim.split(conf_data, '\n', {
      plain = true,
      trimempty = true,
    })
  )

  local height = math.floor(vim.o.lines * 0.85)
  local width = math.floor(vim.o.columns * 0.85)
  local win = vim.api.nvim_open_win(bufnr, true, {
    focusable = true,
    border = 'single',
    col = math.floor((vim.o.columns - width) / 2) - 1,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    relative = 'editor',
    style = 'minimal',
    title = 'Triforce Config',
    title_pos = 'center',
    width = width,
    height = height,
    zindex = 50,
  })

  Util.optset('signcolumn', 'no', 'win', win)
  Util.optset('list', false, 'win', win)
  Util.optset('number', false, 'win', win)
  Util.optset('wrap', false, 'win', win)
  Util.optset('colorcolumn', '', 'win', win)

  Util.optset('filetype', '', 'buf', bufnr)
  Util.optset('fileencoding', 'utf-8', 'buf', bufnr)
  Util.optset('buftype', 'nowrite', 'buf', bufnr)
  Util.optset('modifiable', false, 'buf', bufnr)

  vim.keymap.set('n', 'q', function()
    pcall(vim.api.nvim_win_close, win, true)
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end, { buffer = bufnr })
  vim.keymap.set('n', '<Esc>', function()
    pcall(vim.api.nvim_win_close, win, true)
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end, { buffer = bufnr })
end

---@return string|nil config_str
function M.get_config()
  if not M.config then
    return
  end

  local opts = {} ---@type TriforceConfig
  for k, v in pairs(M.config) do
    opts[k] = v
  end
  return vim.inspect(opts)
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
