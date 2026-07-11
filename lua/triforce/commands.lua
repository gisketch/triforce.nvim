---@module 'triforce.types'

---@class Triforce.Commands
local M = {}

-- Create user commands with subcommands
function M.setup()
  vim.api.nvim_create_user_command('Triforce', function(opts)
    local subcommand = opts.fargs[1]
    local subcommand2 = opts.fargs[2] or '' ---@type string|nil
    local subcommand3 = opts.fargs[3] or ''
    local subcommand4 = opts.fargs[4] or ''
    local triforce = require('triforce')

    if subcommand == 'config' then
      require('triforce.config').open_window()
    elseif subcommand == 'profile' then
      local options = vim.tbl_keys(require('triforce.ui.profile').tabs_map) --[[@as string[]\]]
      if subcommand2 == '' then
        triforce.show_profile()
      elseif vim.list_contains(options, subcommand2) then
        triforce.show_profile(subcommand2)
      else
        local msg = 'Usage:\n    :Triforce profile'
        for _, option in ipairs(options) do
          msg = ('%s\n    :Triforce profile %s'):format(msg, option)
        end
        vim.notify(msg, vim.log.levels.INFO)
      end
    elseif subcommand == 'reset' then
      triforce.reset()
    elseif subcommand == 'items' then
      if subcommand2 == '' then
        vim.notify(
          [[Usage: :Triforce items buy <item>
       :Triforce items currency
       :Triforce items list]],
          vim.log.levels.INFO
        )
      elseif subcommand2 == 'currency' then
        vim.notify(tostring(triforce.tracker.get_stats().currency), vim.log.levels.INFO)
      elseif subcommand2 == 'list' then
        local msg = ''
        for _, item in ipairs(triforce.items.get_items_by_name()) do
          msg = (msg .. (msg == '' and '%s' or '\n%s')):format(item)
        end
        vim.notify(msg, vim.log.levels.INFO)
      elseif subcommand2 == 'buy' then
        if not vim.list_contains(triforce.items.get_items_by_name(), subcommand3) then
          vim.notify('Usage: :Triforce items buy <item>', vim.log.levels.INFO)
        else
          triforce.items.buy_item(subcommand3)
        end
      end
    elseif subcommand == 'stats' then
      if subcommand2 == '' then
        vim.notify(vim.inspect(triforce.get_stats()), vim.log.levels.INFO)
      elseif subcommand2 == 'save' then
        triforce.save_stats()
      elseif subcommand2 ~= 'export' then
        vim.notify(
          [[Usage: :Triforce stats
       :Triforce stats export
       :Triforce stats export json </path/to/file>
       :Triforce stats export markdown </path/to/file>
       :Triforce stats save]],
          vim.log.levels.INFO
        )
      elseif subcommand3 == '' then
        triforce.export_stats()
      elseif not vim.list_contains({ 'json', 'markdown' }, subcommand3) then
        vim.notify(
          [[Usage: :Triforce stats export json <path/to/file>
       :Triforce stats export markdown </path/to/file>]],
          vim.log.levels.INFO
        )
      elseif subcommand3 == 'markdown' then
        if subcommand4 == '' then
          vim.notify('Usage: :Triforce stats export markdown </path/to/file>', vim.log.levels.INFO)
        else
          triforce.export_stats_to_md(subcommand4)
        end
      elseif subcommand4 == '' then
        vim.notify('Usage: :Triforce stats export json </path/to/file>', vim.log.levels.INFO)
      else
        triforce.export_stats_to_json(subcommand4)
      end
    elseif subcommand == 'debug' then
      local debug_ops = {
        xp = triforce.debug_xp,
        achievement = triforce.debug_achievement,
        languages = triforce.debug_languages,
        fix = triforce.debug_fix_level,
      }

      -- Plan B: If subcommand2 value is not valid then abort and print usage
      if not vim.list_contains(vim.tbl_keys(debug_ops), subcommand2) then
        vim.notify('Usage: :Triforce debug xp | achievement | languages | fix', vim.log.levels.INFO)
      else
        local operation = debug_ops[subcommand2]
        operation()
      end
    else
      vim.notify(
        [[Usage: :Triforce config
       :Triforce debug <xp|achievement|languages|fix>
       :Triforce items buy <item>
       :Triforce items <currency|list>
       :Triforce profile
       :Triforce reset
       :Triforce stats
       :Triforce stats export
       :Triforce stats export json <path/to/file>
       :Triforce stats export markdown </path/to/file>
       :Triforce stats save]],
        vim.log.levels.INFO
      )
    end
  end, {
    nargs = '*',
    desc = 'Triforce gamification commands',
    complete = function(_, line)
      local args = vim.split(line, '%s+', { trimempty = false })
      if args[1]:sub(-1) == '!' then
        return {}
      end

      if #args == 2 then
        if args[2] == '' then
          return { 'profile', 'stats', 'reset', 'debug', 'config', 'items' }
        end
        local res = {} ---@type string[]
        for _, comp in ipairs({ 'profile', 'stats', 'reset', 'debug', 'config', 'items' }) do
          if vim.startswith(comp, args[2]) then
            table.insert(res, comp)
          end
        end
        return res
      end
      if #args == 3 then
        if args[2] == 'debug' then
          if args[3] == '' then
            return { 'xp', 'achievement', 'languages', 'fix' }
          end
          local res = {} ---@type string[]
          for _, comp in ipairs({ 'xp', 'achievement', 'languages', 'fix' }) do
            if vim.startswith(comp, args[3]) then
              table.insert(res, comp)
            end
          end
          return res
        end
        if args[2] == 'stats' then
          if args[3] == '' then
            return { 'export', 'save' }
          end
          local res = {} ---@type string[]
          for _, comp in ipairs({ 'export', 'save' }) do
            if vim.startswith(comp, args[3]) then
              table.insert(res, comp)
            end
          end
          return res
        end
        if args[2] == 'profile' then
          if args[3] == '' then
            return vim.tbl_keys(require('triforce.ui.profile').tabs_map)
          end
          local res = {} ---@type string[]
          for _, comp in ipairs(require('triforce.ui.profile').tabs_map) do
            if vim.startswith(comp, args[3]) then
              table.insert(res, comp)
            end
          end
          return res
        end
        if args[2] == 'items' then
          local res = {} ---@type string[]
          for _, comp in ipairs({ 'buy', 'currency', 'list' }) do
            if vim.startswith(comp, args[3]) then
              table.insert(res, comp)
            end
          end
          return res
        end
      end
      if #args >= 4 and args[2] == 'items' and args[3] == 'buy' then
        local items = require('triforce.items').get_items_by_name()
        local used, res = {}, {} ---@type string[], string[]
        for i = 4, #args - 1 do
          if not vim.list_contains(items, args[i]) then
            return res
          end
          table.insert(used, args[i])
        end
        for _, item in ipairs(items) do
          if vim.startswith(item, args[#args]) and not vim.list_contains(used, item) then
            table.insert(res, item)
          end
        end
        return res
      end
      if #args >= 4 and args[2] == 'stats' and args[3] == 'export' then
        if #args == 4 then
          if args[4] == '' then
            return { 'json', 'markdown' }
          end
          local res = {} ---@type string[]
          for _, comp in ipairs({ 'json', 'markdown' }) do
            if vim.startswith(comp, args[4]) then
              table.insert(res, comp)
            end
          end
          return res
        end
        if #args == 5 and vim.list_contains({ 'json', 'markdown' }, args[4]) then
          return vim.fn.getcompletion(args[5], 'file', true)
        end
      end
      return {}
    end,
  })
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
