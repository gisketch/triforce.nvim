local assert = require('luassert') ---@type Luassert

describe('triforce', function()
  local triforce ---@type Triforce
  local levels ---@type Triforce.Levels

  before_each(function()
    -- Clear module cache to get fresh instance
    package.loaded.triforce = nil
    triforce = require('triforce')
    levels = require('triforce.levels')
  end)

  describe('levels', function()
    it('should parse custom levels', function()
      local lvls = { ---@type LevelParams[]
        { level = 3, title = 'Test 1' },
        { level = 5, title = 'Test 2' },
        { level = 8, title = 'Test 3' },
      }

      local ok = pcall(triforce.setup, { levels = lvls })
      assert.is_true(ok)

      for _, lvl in ipairs(lvls) do
        assert.is_same((lvl.icon or '') .. ' ' .. lvl.title, levels.get_level_title(lvl.level))
      end
    end)

    it('should fail on missing custom level field', function()
      ---@diagnostic disable:missing-fields
      local lvls = { ---@type LevelParams[]
        { title = 'Test 1' },
        { level = 600 },
        { title = 'Test 3' },
      }
      ---@diagnostic enable:missing-fields

      local ok = pcall(triforce.setup, { levels = lvls })
      assert.is_false(ok)
    end)
  end)
end)
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
