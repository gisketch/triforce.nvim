---@class Triforce.Ui
---@field profile Triforce.Ui.Profile
local M = setmetatable({}, {
  __index = function(_, k)
    if require('triforce.util').mod_exists('triforce.ui.' .. k) then
      return require('triforce.ui.' .. k)
    end
  end,
})

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
