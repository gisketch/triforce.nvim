---@class TriforceOpts.Items
---@field enabled? boolean

local uv = vim.uv or vim.loop
local ERROR = vim.log.levels.ERROR
local Util = require('triforce.util')

local items_path = vim.fs.joinpath(vim.fn.stdpath('state'), 'triforce_items.json')

---@class Triforce.Items.Spec
---@field base_price integer
---@field callback fun(self: Triforce.Items.FullSpec, stats: Stats): success: boolean
---@field desc string
---@field filetypes? string[]
---@field level_cap? nil|fun(self: Triforce.Items.FullSpec): cap: integer
---@field max_uses? integer
---@field name string
---@field once? boolean
---@field times_used? integer
---@field price? fun(self: Triforce.Items.FullSpec, stats: Stats): price: integer

---@class Triforce.Items
local M = {}

---@class Triforce.Items.FullSpec: Triforce.Items.Spec
---@field callback fun(self: Triforce.Items.FullSpec, stats: Stats): success: boolean
---@field filetypes string[]
---@field level_cap integer
---@field max_uses integer
---@field once boolean
---@field price nil|fun(self: Triforce.Items.FullSpec, stats: Stats): price: integer
---@field times_used integer
---@field used boolean
local Item = {}

---@param stats Stats
function Item:available(stats)
  if self.level_cap > 0 and stats.level >= self.level_cap then
    vim.notify('(triforce.nvim): Level is higher than the limit!', ERROR)
    return false
  end
  if stats.currency < self:price(stats) then
    vim.notify('(triforce.nvim): Not enough currency!', ERROR)
    return false
  end
  if self.once and self.times_used > 0 then
    vim.notify('(triforce.nvim): Item cannot be used again!', ERROR)
    return false
  end
  if not self.once and self.max_uses < self.times_used then
    vim.notify('(triforce.nvim): Item cannot be used more than its maximum!', ERROR)
    return false
  end
  return true
end

---@param T Triforce.Items.Spec
---@return Triforce.Items.FullSpec item
function Item:new(T)
  local item = setmetatable(T, { __index = Item }) ---@type Triforce.Items.FullSpec
  item.max_uses = T.max_uses or 0
  item.level_cap = T.level_cap and T.level_cap(item) or 0
  item.filetypes = T.filetypes or {}
  item.times_used = 0
  item.used = false

  local cb = item.callback
  item.callback = function(O, stats)
    if not O:available(stats) then
      return false
    end
    return cb(item, stats)
  end
  return item
end

local items = { ---@type table<string, Triforce.Items.Spec>
  xp_boost = {
    name = 'Single XP Boost',
    desc = 'Use this for a rapid XP boost to the next XP tier (unavailable for max tier).',
    once = false,
    base_price = 500,
    max_uses = 0,
    price = function(self, stats)
      return math.floor(self.base_price * (self.times_used <= 0 and 1 or (math.log(self.times_used) + stats.level)))
    end,
    level_cap = function()
      return require('triforce.stats').level_config.tier_10.min_level
    end,
    callback = function(self, stats)
      local Stats = require('triforce.stats')
      local level_boost = nil ---@type integer|nil
      for _, tier in pairs(Stats.level_config) do
        ---@cast tier LevelTier
        if stats.level >= tier.min_level and stats.level <= tier.max_level and tier.max_level ~= math.huge then
          level_boost = tier.max_level - stats.level + 1
          break
        end
      end

      if not level_boost then
        vim.notify('(triforce.nvim) Unable to boost higher!', ERROR)
        return false
      end
      self.times_used = self.times_used + 1
      return Stats.add_xp(stats, Stats.xp_for_next_level(stats.level + level_boost))
    end,
  },
}

local all_items = {} ---@type table<string, Triforce.Items.FullSpec>
local event = nil ---@type uv.uv_fs_event_t|nil

local function setup_watch()
  if vim.g.triforce_items_loaded == 1 and event then
    return
  end

  event = uv.new_fs_event()
  if not event then
    vim.notify('(triforce.nvim): Unable to setup item file setup event!', ERROR)
    return
  end

  event:start(items_path, {}, function(err, filename, events)
    if err or not events.change then
      if err then
        vim.notify(('Error while watching events for `%s`:\n%s'):format(filename, err), ERROR)
      end
      return
    end
    M.read_items()
  end)

  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = vim.api.nvim_create_augroup('TriforceItems', { clear = true }),
    once = true,
    callback = function()
      if event then
        event:stop()
        event = nil
      end
    end,
  })

  vim.g.triforce_items_loaded = 1
end

---@param json? boolean
function M.get_items(json)
  if json == nil then
    json = false
  end

  if not json then
    return all_items
  end

  local json_items = {}
  for k, item in pairs(all_items) do
    local tbl = {}
    for name, v in pairs(item) do
      if type(v) ~= 'function' then
        tbl[name] = v
      end
    end
    json_items[k] = tbl
  end
  return json_items
end

function M.read_items()
  local stat = uv.fs_stat(items_path)
  if not stat then
    local fd = uv.fs_open(items_path, 'w', tonumber('644', 8))
    if not fd then
      error(('Error while opening %s'):format(items_path))
    end
    uv.fs_write(fd, vim.json.encode(M.get_items(true)))
    uv.fs_close(fd)
    return
  end

  local fd = uv.fs_open(items_path, 'r', tonumber('644', 8))
  if not fd then
    return
  end

  local ok, raw_data = pcall(uv.fs_read, fd, stat.size)
  uv.fs_close(fd)
  if not (ok and raw_data) then
    return
  end

  local json_ok, data = pcall(vim.json.decode, raw_data) ---@type boolean, table<string, Triforce.Items.FullSpec>|nil|?
  if not (json_ok and data) then
    return
  end
  for name, item in pairs(data) do
    for k, v in pairs(item) do
      all_items[name][k] = v
    end
  end
end

function M.save_items()
  local stat = uv.fs_stat(items_path)
  if not stat or stat.size == 0 then
    local fd = uv.fs_open(items_path, 'w', tonumber('644', 8))
    if not fd then
      error(('Error while opening %s'):format(items_path))
    end
    uv.fs_write(fd, vim.json.encode(M.get_items(true)))
    uv.fs_close(fd)
    return
  end

  local fd = uv.fs_open(items_path, 'w', tonumber('644', 8))
  if not fd then
    return
  end

  local json_ok, data = pcall(vim.json.encode, M.get_items(true))
  if json_ok and data then
    uv.fs_write(fd, data)
  end
  uv.fs_close(fd)
end

---@param id string
---@return boolean|nil|? used
function M.item_used(id)
  return all_items[id] and all_items[id].used or nil
end

---@param id string
---@return integer|nil|? price
function M.item_price(id)
  if not (all_items[id] and all_items[id].price) then
    return
  end
  return all_items[id]:price(require('triforce.tracker').get_stats())
end

---@param id string
---@return boolean|nil|? capped
---@return integer|nil|? level
function M.item_capped(id)
  if not all_items[id] then
    return
  end
  return all_items[id].level_cap ~= 0, all_items[id].level_cap
end

---@param id string
---@return boolean success
function M.buy_item(id)
  if vim.g.triforce_items_loaded ~= 1 then
    return false
  end

  local res = all_items[id]:callback(require('triforce.tracker').get_stats())
  M.save_items()
  return res
end

function M.reset_all_items()
  if vim.g.triforce_items_loaded == 1 then
    for name, item in pairs(all_items) do
      item.times_used = 0
      all_items[name] = vim.deepcopy(item)
    end

    local fd = uv.fs_open(items_path, 'w', tonumber('644', 8))
    if not fd then
      return
    end

    uv.fs_ftruncate(fd, 0)
    uv.fs_close(fd)

    M.save_items()
  end
end

---@param opts TriforceConfigDefaults.Items
function M.setup(opts)
  Util.validate({ opts = { opts, { 'table' } } })
  if vim.g.triforce_items_loaded ~= 1 and opts.enabled then
    for id, item_spec in pairs(items) do
      all_items[id] = Item:new(item_spec)
    end
    M.read_items()
    M.save_items()

    setup_watch()
  end
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
