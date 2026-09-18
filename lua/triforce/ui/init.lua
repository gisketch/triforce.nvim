---@class Triforce.Ui
---@field profile Triforce.Ui.Profile
local M = setmetatable({}, {
  __index = function(self, k)
    local raw = rawget(self, k) or nil
    if raw then
      return raw
    end
    if require('triforce.util').mod_exists('triforce.ui.' .. k) then
      rawset(self, k, require('triforce.ui.' .. k))
      return require('triforce.ui.' .. k)
    end
  end,
})

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
