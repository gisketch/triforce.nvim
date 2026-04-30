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
  ignore_ft = {},
  keymap = { show_profile = '' },
  levels = {},
  level_progression = {
    tier_1 = { min_level = 1, max_level = 10, xp_per_level = 300 },
    tier_2 = { min_level = 11, max_level = 20, xp_per_level = 500 },
    tier_3 = { min_level = 21, max_level = 30, xp_per_level = 1000 },
    tier_4 = { min_level = 31, max_level = 40, xp_per_level = 2000 },
    tier_5 = { min_level = 41, max_level = 50, xp_per_level = 3000 },
    tier_6 = { min_level = 51, max_level = 75, xp_per_level = 5000 },
    tier_7 = { min_level = 76, max_level = 100, xp_per_level = 7500 },
    tier_8 = { min_level = 101, max_level = 150, xp_per_level = 10000 },
    tier_9 = { min_level = 151, max_level = 225, xp_per_level = 15000 },
    tier_10 = { min_level = 226, max_level = 300, xp_per_level = 20000 },
  },
  notifications = { enabled = true, level_up = true, achievements = true },
  override_levels = false,
  xp_rewards = { char = 1, line = 1, save = 50 },
}

---@class Triforce.Config
---Setup options.
--- ---
---@field config TriforceConfigDefaults
local Config = {}

---@param silent? boolean
---@return boolean gamified
function Config.has_gamification(silent)
  Util.validate({ silent = { silent, { 'boolean', 'nil' }, true } })
  if silent == nil then
    silent = false
  end

  if Config.config.gamification_enabled ~= nil and Config.config.gamification_enabled then
    return true
  end

  if not silent then
    vim.notify('Gamification is not enabled in config', vim.log.levels.WARN)
  end
  return false
end

---@return TriforceConfigDefaults defaults
function Config.defaults()
  return defaults
end

---@param opts? TriforceConfig
function Config.new_config(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  Config.config = setmetatable(vim.tbl_deep_extend('keep', opts or {}, Config.defaults()), {
    __index = defaults,
  })

  local keys = vim.tbl_keys(Config.defaults()) --[[@as string[]\]]
  for k, _ in pairs(Config.config) do
    ---@cast k string
    if not vim.list_contains(keys, k) then
      Config.config[k] = nil
    end
  end

  if Config.config.backdrop and Config.config.backdrop.winblend then
    if Config.config.backdrop.winblend >= 100 then
      Config.config.backdrop.winblend = 100
    elseif Config.config.backdrop.winblend <= 0 then
      Config.config.backdrop.winblend = 0
    end
  end
end

---Setup the plugin with user configuration
--- ---
---@param opts? TriforceConfig User configuration options.
function Config.setup(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  Config.new_config(opts or {})

  if not Config.config.enabled then
    return
  end

  local stats_module = require('triforce.stats')
  local langs_module = require('triforce.languages')

  -- Apply custom level progression to stats module
  if Config.config.level_progression then
    stats_module.level_config = Config.config.level_progression
    stats_module.calibrate_tiers()
  end

  -- Register custom languages if provided
  if Config.config.custom_languages then
    langs_module.register_custom_languages(Config.config.custom_languages)
  end

  if Config.config.ignore_ft then
    langs_module.exclude_langs(Config.config.ignore_ft)
  end

  -- Setup custom path if provided
  stats_module.db_path = Config.config.db_path
end

function Config.open_window()
  local bufnr = vim.api.nvim_create_buf(false, true)
  local conf_data = Config.get_config() or ''
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
function Config.get_config()
  if not Config.config then
    return
  end

  local opts = {} ---@type TriforceConfig
  for k, v in pairs(Config.config) do
    opts[k] = v
  end
  return vim.inspect(opts)
end

return Config
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
