---Health check for triforce.nvim
---
---Run with `:checkhealth triforce`
--- ---
---@class Triforce.Health
local M = {}

function M.check()
  vim.health.start('Version Check')
  local nvim_version = vim.version()
  if nvim_version.major == 0 and nvim_version.minor >= 9 then
    vim.health.ok(('Neovim version: %s.%s.%s'):format(nvim_version.major, nvim_version.minor, nvim_version.patch))
  else
    vim.health.error('Neovim >= 0.9.0 is required')
  end

  vim.health.start('triforce.nvim')
  local ok, triforce = pcall(require, 'triforce')
  if not ok then
    vim.health.error(('Failed to load triforce module: %s'):format(vim.inspect(triforce)))
    return
  end
  vim.health.ok('triforce module loaded successfully')

  vim.health.start('Triforce Config')
  local conf_ok, config = pcall(require, 'triforce.config')
  if not conf_ok then
    vim.health.error('Failed to load triforce config')
    return
  end

  if not config.get().enabled then
    vim.health.warn('Triforce is disabled in configuration')
    return
  end

  vim.health.ok('Plugin is enabled')

  vim.health.start('Gamification')
  if not config.get().gamification_enabled then
    vim.health.warn('Gamification is disabled')
    return
  end
  vim.health.ok('Gamification is enabled')

  vim.health.start('Stats File')
  local stats_path = vim.fs.joinpath(vim.fn.stdpath('data'), 'triforce_stats.json')
  if vim.fn.filereadable(stats_path) == 1 then
    vim.health.ok(('Stats file found: `%s`'):format(stats_path))
    return
  end
  vim.health.info('Stats file not yet created (will be created on first use)')
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
