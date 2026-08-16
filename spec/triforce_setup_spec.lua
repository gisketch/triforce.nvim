local assert = require('luassert') --[[@as Luassert]]

describe('triforce', function()
  local triforce ---@type Triforce
  local config ---@type Triforce.Config

  before_each(function()
    -- Clear module cache to get fresh instance
    package.loaded.triforce = nil
    triforce = require('triforce')
    config = require('triforce.config')
  end)

  describe('setup', function()
    it('should set default configuration', function()
      local ok = pcall(triforce.setup)
      assert.is_true(ok)
      assert.is_true(config.get().enabled)
    end)

    it('should merge user configuration with defaults', function()
      local ok = pcall(triforce.setup, { enabled = false })
      assert.is_true(ok)
      assert.is_false(config.get().enabled)
    end)

    it('should handle empty table parameter', function()
      local ok = pcall(triforce.setup, {})
      assert.is_true(ok)
      assert.is_true(config.get().enabled)
    end)

    it('should handle nil options', function()
      local ok = pcall(triforce.setup, nil)
      assert.is_true(ok)
      assert.is_true(config.get().enabled)
    end)

    it('should purge any invalid keys', function()
      local ok = pcall(triforce.setup, { foo = 'bar' })
      assert.is_true(ok)
      assert.are_same(config.get(), config.defaults())
    end)

    local params = { 1, false, '', function() end }
    for _, param in ipairs(params) do
      it(('should throw error when called with param of type %s'):format(type(param)), function()
        local ok = pcall(triforce.setup, param)
        assert.is_false(ok)
      end)
    end
  end)
end)
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
