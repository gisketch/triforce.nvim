local assert = require('luassert') --[[@as Luassert]]

describe('triforce', function()
  local triforce ---@type Triforce
  local achievement ---@type Triforce.Achievements

  before_each(function()
    -- Clear module cache to get fresh instance
    package.loaded.triforce = nil
    triforce = require('triforce')
    achievement = require('triforce.achievement')
    triforce.setup()
  end)

  describe('achievement', function()
    it('should accept new achievements', function()
      local get_stats = require('triforce.tracker').get_stats
      local achv = {
        id = 'test_achv_1',
        name = 'Test Achievement #1',
        check = function()
          return true
        end,
        desc = 'Test achievement #1',
      }
      local ok, stats
      ok, stats = pcall(get_stats)
      assert.is_true(ok)

      ok = pcall(achievement.new_achievements, achv, stats)
      assert.is_true(ok)

      local all_achv = achievement.get_all_achievements(stats)
      assert.is_equal(achv, all_achv[#all_achv])
    end)

    it('should fail on incomplete new achievement', function()
      local get_stats = require('triforce.tracker').get_stats
      local achv = {
        {
          id = 'test_achv_1',
          desc = 'Test achievement #1',
        },
        {
          desc = 'Test achievement #1',
          check = function()
            return true
          end,
        },
      }
      local ok, stats
      ok, stats = pcall(get_stats)
      assert.is_true(ok)

      ok = pcall(achievement.new_achievements, achv, stats)
      assert.is_false(ok)
    end)

    it('should fail new achievements on bad parameter types', function()
      local get_stats = require('triforce.tracker').get_stats
      local ok, stats
      ok, stats = pcall(get_stats)
      assert.is_true(ok)

      ok = pcall(achievement.new_achievements, true, stats)
      assert.is_false(ok)
      ok = pcall(achievement.new_achievements, 1, stats)
      assert.is_false(ok)
      ok = pcall(achievement.new_achievements, function() end, stats)
      assert.is_false(ok)
    end)
  end)
end)
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
