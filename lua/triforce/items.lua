---@class TriforceOpts.Items
---@field enabled? boolean

local ERROR = vim.log.levels.ERROR
local Util = require('triforce.util')
local timers = {} ---@type table<string, uv.uv_timer_t>

local items_path = vim.fs.joinpath(vim.fn.stdpath('state'), 'triforce_items.json')

---@class Triforce.Items.Spec
---@field base_price integer
---@field callback fun(self: Triforce.Items.FullSpec, stats: Stats): success: boolean, stats: Stats|?
---@field desc string
---@field filetypes? string[]
---@field level_cap? nil|fun(self: Triforce.Items.FullSpec): cap: number
---@field max_uses? integer
---@field name string
---@field once? boolean
---@field price? fun(self: Triforce.Items.FullSpec, stats: Stats): price: integer
---@field times_used? integer

---@class Triforce.Items
local M = {}

---@class Triforce.Items.FullSpec: Triforce.Items.Spec
---@field callback fun(self: Triforce.Items.FullSpec, stats: Stats): success: boolean, stats: Stats|?
---@field filetypes string[]
---@field level_cap number
---@field max_uses integer
---@field once boolean
---@field price nil|fun(self: Triforce.Items.FullSpec, stats: Stats): price: integer
---@field times_used integer
---@field used boolean
local Item = {}

---@param stats Stats
---@param no_notify? boolean
function Item.available(self, stats, no_notify)
  Util.validate({
    stats = { stats, { 'table' } },
    no_notify = { no_notify, { 'boolean', 'nil' }, true },
  })
  if no_notify == nil then
    no_notify = false
  end
  if self.level_cap > 0 and stats.level >= self.level_cap then
    if not no_notify then
      vim.notify('(triforce.nvim): Level is higher than the limit!', ERROR)
    end
    return false
  end
  if stats.currency < self.price(self, stats) then
    if not no_notify then
      vim.notify('(triforce.nvim): Not enough currency!', ERROR)
    end
    return false
  end
  if self.once and self.times_used > 0 then
    if not no_notify then
      vim.notify('(triforce.nvim): Item cannot be used again!', ERROR)
    end
    return false
  end
  if not self.once and self.max_uses > 0 and self.max_uses <= self.times_used then
    if not no_notify then
      vim.notify('(triforce.nvim): Item cannot be used more than its maximum!', ERROR)
    end
    return false
  end
  return true
end

---@param T Triforce.Items.Spec
---@return Triforce.Items.FullSpec item
function Item.new(T)
  local item = setmetatable(T, { __index = Item }) ---@type Triforce.Items.FullSpec
  item.max_uses = T.max_uses or 0
  item.level_cap = T.level_cap and T.level_cap(item) or 0
  item.filetypes = T.filetypes or {}
  item.times_used = 0
  item.used = false

  local cb = item.callback
  item.callback = function(self, stats)
    local filetype = Util.optget('filetype', 'buf', vim.api.nvim_get_current_buf()) --[[@as string]]
    local is_ft = vim.tbl_isempty(self.filetypes)
    for _, ft in ipairs(self.filetypes) do
      if vim.list_contains({ '*', filetype }, ft) then
        is_ft = true
        break
      end
    end
    if not (is_ft and self.available(self, stats)) then
      return false, stats
    end

    stats.currency = stats.currency - self:price(stats)
    self.times_used = self.times_used + 1
    return cb(item, stats), stats
  end
  return item
end

local items = { ---@type table<string, Triforce.Items.Spec>
  level_up_1x = {
    name = 'Level up (1x)',
    desc = 'Use this to level up once (CAN ONLY BE USED 5 TIMES!).',
    once = false,
    max_uses = 5,
    base_price = 500,
    price = function(self, stats)
      return math.floor(self.base_price + (self.times_used <= 0 and 0 or stats.level * self.times_used))
    end,
    callback = function(_, stats)
      local Stats = require('triforce.stats')
      local res, new_stats = Stats.add_xp(stats, Stats.xp_for_next_level(stats.level) - stats.xp, false)
      require('triforce.tracker').update_stats(new_stats)
      return res
    end,
  },
  xp_boost = {
    name = 'Single XP Boost',
    desc = 'Use this for a rapid XP boost to the next XP tier (unavailable for max tier).',
    once = false,
    base_price = 2500,
    max_uses = 0,
    price = function(self)
      return math.floor(self.base_price * (self.times_used <= 0 and 1 or self.times_used))
    end,
    level_cap = function()
      return require('triforce.stats').get_level_config().tier_10.min_level
    end,
    callback = function(_, stats)
      local Stats = require('triforce.stats')
      local level_boost = nil ---@type integer|nil|?
      for _, tier in pairs(Stats.get_level_config()) do
        ---@cast tier LevelTier
        if stats.level >= tier.min_level and stats.level <= tier.max_level then
          level_boost = tier.max_level - stats.level + 1
          break
        end
      end

      if not level_boost then
        vim.notify('(triforce.nvim) Unable to boost higher!', ERROR)
        return false
      end
      local res, new_stats = Stats.add_xp(stats, Stats.xp_for_next_level(stats.level + level_boost) - stats.xp, false)
      require('triforce.tracker').update_stats(new_stats)
      return res
    end,
  },
  xp_timer_2x = {
    name = 'XP Multiplier (2X, 30 minutes)',
    desc = 'Duplicate your XP gain for 30 minutes. Closing Neovim will cancel this timer!',
    base_price = 500,
    once = false,
    price = function(self)
      return self.base_price
    end,
    callback = function()
      if timers.xp_timer_2x then
        if timers.xp_timer_2x:is_active() then
          timers.xp_timer_2x:close()
        end
        timers.xp_timer_2x = nil
      end

      timers.xp_timer_2x = vim.uv.new_timer()
      if not timers.xp_timer_2x then
        vim.notify('(triforce.nvim): Unable to create timer!')
        return false
      end

      local Stats = require('triforce.stats')
      Stats.set_xp_multiplier(2)
      timers.xp_timer_2x:start(
        30 * 60 * 1000, -- minutes * seconds * milliseconds
        0,
        vim.schedule_wrap(function()
          Stats.set_xp_multiplier(1)
        end)
      )
      return true
    end,
  },
  xp_timer_3x = {
    name = 'XP Multiplier (3X, 15 minutes)',
    desc = 'Triplicate your XP gain for 15 minutes (cannot be stacked). Closing Neovim will cancel this timer!',
    base_price = 1250,
    once = false,
    price = function(self)
      return self.base_price
    end,
    callback = function()
      if timers.xp_timer_3x then
        if timers.xp_timer_3x:is_active() then
          timers.xp_timer_3x:close()
        end
        timers.xp_timer_3x = nil
      end

      timers.xp_timer_3x = vim.uv.new_timer()
      if not timers.xp_timer_3x then
        vim.notify('(triforce.nvim): Unable to create timer!')
        return false
      end

      local Stats = require('triforce.stats')
      Stats.set_xp_multiplier(3)
      timers.xp_timer_3x:start(
        15 * 60 * 1000, -- minutes * seconds * milliseconds
        0,
        vim.schedule_wrap(function()
          Stats.set_xp_multiplier(1)
        end)
      )
      return true
    end,
  },
  xp_timer_5x = {
    name = 'XP Multiplier (5X, 5 minutes)',
    desc = 'Multiplie your XP gain by 5, for 5 minutes (cannot be stacked). Closing Neovim will cancel this timer!',
    base_price = 2000,
    once = false,
    price = function(self)
      return self.base_price
    end,
    callback = function()
      if timers.xp_timer_5x then
        if timers.xp_timer_5x:is_active() then
          timers.xp_timer_5x:close()
        end
        timers.xp_timer_5x = nil
      end

      timers.xp_timer_5x = vim.uv.new_timer()
      if not timers.xp_timer_5x then
        vim.notify('(triforce.nvim): Unable to create timer!')
        return false
      end

      local Stats = require('triforce.stats')
      Stats.set_xp_multiplier(5)
      timers.xp_timer_5x:start(
        5 * 60 * 1000, -- minutes * seconds * milliseconds
        0,
        vim.schedule_wrap(function()
          Stats.set_xp_multiplier(1)
        end)
      )
      return true
    end,
  },
}

local all_items = {} ---@type table<string, Triforce.Items.FullSpec>
local event = nil ---@type uv.uv_fs_event_t|nil|?

local function setup_watch()
  if vim.g.triforce_items_loaded == 1 and event then
    return
  end

  event = vim.uv.new_fs_event()
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
---@return table<string, Triforce.Items.FullSpec> items
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
  local stat = vim.uv.fs_stat(items_path)
  if not stat then
    local fd = vim.uv.fs_open(items_path, 'w', tonumber('644', 8))
    if not fd then
      error(('Error while opening %s'):format(items_path))
    end
    vim.uv.fs_write(fd, vim.json.encode(M.get_items(true)))
    vim.uv.fs_close(fd)
    return
  end

  local fd = vim.uv.fs_open(items_path, 'r', tonumber('644', 8))
  if not fd then
    return
  end

  local ok, raw_data = pcall(vim.uv.fs_read, fd, stat.size)
  vim.uv.fs_close(fd)
  if not (ok and raw_data) then
    return
  end

  local json_ok, data = pcall(vim.json.decode, raw_data) ---@type boolean, table<string, Triforce.Items.FullSpec>|nil|?
  if not (json_ok and data) then
    return
  end
  for name, item in pairs(data) do
    for k, v in pairs(item) do
      ---@cast k string
      if all_items[name][k] == nil then
        all_items[name][k] = v
      end
    end
  end
end

function M.save_items()
  local stat = vim.uv.fs_stat(items_path)
  if not stat or stat.size == 0 then
    local fd = vim.uv.fs_open(items_path, 'w', tonumber('644', 8))
    if not fd then
      error(('Error while opening %s'):format(items_path))
    end
    vim.uv.fs_write(fd, vim.json.encode(M.get_items(true)))
    vim.uv.fs_close(fd)
    return
  end

  local fd = vim.uv.fs_open(items_path, 'w', tonumber('644', 8))
  if fd then
    local json_ok, data = pcall(vim.json.encode, M.get_items(true))
    if json_ok and data then
      vim.uv.fs_write(fd, data)
    end
    vim.uv.fs_close(fd)
  end
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
  return all_items[id].price(all_items[id], require('triforce.tracker').get_stats())
end

---@param id string
---@return boolean|nil|? capped
---@return number|nil|? level
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

  local res, stats = all_items[id]:callback(require('triforce.tracker').get_stats())
  M.save_items()

  if stats then
    require('triforce.tracker').update_stats(stats)
  end
  return res
end

function M.reset_all_items()
  if vim.g.triforce_items_loaded == 1 then
    for name, item in pairs(all_items) do
      item.times_used = 0
      all_items[name] = vim.deepcopy(item)
    end

    local fd = vim.uv.fs_open(items_path, 'w', tonumber('644', 8))
    if fd then
      vim.uv.fs_ftruncate(fd, 0)
      vim.uv.fs_close(fd)

      M.save_items()
    end
  end
end

---@param opts TriforceConfigDefaults.Items
function M.setup(opts)
  Util.validate({ opts = { opts, { 'table' } } })
  if vim.g.triforce_items_loaded ~= 1 and opts.enabled then
    for id, item_spec in pairs(items) do
      all_items[id] = Item.new(item_spec)
    end
    M.read_items()
    M.save_items()

    setup_watch()

    vim.api.nvim_create_autocmd('VimLeavePre', {
      group = vim.api.nvim_create_augroup('TriforceItems', { clear = false }),
      once = true,
      callback = function()
        for name, timer in pairs(timers) do
          if timer:is_active() then
            timer:stop()
            timers[name] = nil
          end
        end
      end,
    })
  end
end

---@return string[] names
function M.get_items_by_name()
  local names = {} ---@type string[]
  for name in pairs(all_items) do
    table.insert(names, name)
  end
  return names
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
