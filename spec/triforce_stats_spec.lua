local assert = require('luassert') --[[@as Luassert]]

describe('triforce', function()
  local triforce ---@type Triforce
  local stats ---@type Triforce.Stats

  before_each(function()
    -- Clear module cache to get fresh instance
    package.loaded.triforce = nil
    triforce = require('triforce')
    triforce.setup()
  end)

  describe('stats', function()
    before_each(function()
      stats = require('triforce.stats')
    end)

    describe('saving', function()
      for _, param in ipairs({ 1, function() end, true }) do
        it(('should fail if path is a %s'):format(type(param)), function()
          assert.is_false((pcall(stats.save, nil, param)))
        end)
      end
    end)

    describe('export', function()
      describe('to JSON', function()
        local fpath = 'spec/.stats.json'
        it('should export to stats with a given path', function()
          assert.is_true((pcall(triforce.export_stats_to_json, fpath)))
          os.remove(fpath)
        end)

        it('should throw error when path is not valid', function()
          assert.is_false((pcall(triforce.export_stats_to_json, '.anyarbitrarydirectory/specs.json')))
        end)

        it('should throw error when nil path is passed', function()
          assert.is_false((pcall(triforce.export_stats_to_json, nil)))
        end)
      end)

      describe('to Markdown', function()
        local fpath = 'spec/.stats.md'
        it('should export to stats with a given path', function()
          assert.is_true((pcall(triforce.export_stats_to_md, fpath)))
          pcall(os.remove, fpath)
        end)

        it('should throw error when path is not valid', function()
          assert.is_false((pcall(triforce.export_stats_to_md, '.anyarbitrarydirectory/specs.md')))
        end)

        it('should throw error when nil path is passed', function()
          assert.is_false((pcall(triforce.export_stats_to_md, nil)))
        end)
      end)
    end)
  end)
end)
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
