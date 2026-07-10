---@meta
---@diagnostic disable:unused-local

---@enum (key) TriforceIconEngine
local icon_engines = { builtin = 1, mini = 1 }

---@class LevelTier
---Ending level for this tier (use `math.huge` for infinite).
--- ---
---@field max_level integer
---Starting level for this tier.
--- ---
---@field min_level integer
---XP required per level in this tier.
--- ---
---@field xp_per_level integer

---@class LevelTier10: LevelTier
---@field max_level number

---@class LevelProgression
---Default: Levels 1-10, 300 XP each.
--- ---
---@field tier_1 LevelTier
---Default: Levels 11-20, 500 XP each.
--- ---
---@field tier_2 LevelTier
---Default: Levels 21-30, 1000 XP each.
--- ---
---@field tier_3 LevelTier
---Default: Levels 31-40, 2000 XP each.
--- ---
---@field tier_4 LevelTier
---Default: Levels 41-50, 3000 XP each.
--- ---
---@field tier_5 LevelTier
---Default: Levels 51-75, 5000 XP each.
--- ---
---@field tier_6 LevelTier
---Default: Levels 76-100, 7500 XP each.
--- ---
---@field tier_7 LevelTier
---Default: Levels 101-150, 10000 XP each.
--- ---
---@field tier_8 LevelTier
---Default: Levels 151-225, 12500 XP each.
--- ---
---@field tier_9 LevelTier
---Default: Levels 226+, 15000 XP each.
--- ---
---@field tier_10 LevelTier10

---@class XPRewards
---XP gained per character typed (default: `1`).
--- ---
---@field char? number
---XP gained per new line (default: `1`).
--- ---
---@field line? number
---XP gained per file save (default: `10`).
--- ---
---@field save? number

---Notification configuration.
--- ---
---@class TriforceConfig.Notifications
---Show achievement unlock notifications.
--- ---
---@field achievements? boolean
---Show level up and achievement notifications.
--- ---
---@field enabled? boolean
---Show level up notifications.
--- ---
---@field level_up? boolean

---@class TriforceConfigDefaults.Notifications: TriforceConfig.Notifications
---@field achievements boolean
---@field enabled boolean
---@field level_up boolean

---Default highlight groups for the heats.
--- ---
---@class TriforceConfig.Heat
---@field TriforceHeat0? string
---@field TriforceHeat1? string
---@field TriforceHeat2? string
---@field TriforceHeat3? string
---@field TriforceHeat4? string

---@class TriforceConfigDefaults.Heat: TriforceConfig.Heat
---@field TriforceHeat0 string
---@field TriforceHeat1 string
---@field TriforceHeat2 string
---@field TriforceHeat3 string
---@field TriforceHeat4 string

---@class TriforceConfig.Backdrop
---Whether to enable the backdrop (i.e. dimming the background).
---
---Defaults to `true`.
--- ---
---@field enabled? boolean
---The amount of transparency for the window (0-100).
--- ---
---@field winblend? integer

---@class TriforceConfigDefaults.Backdrop: TriforceConfig.Backdrop
---@field enabled boolean
---@field winblend integer

---@class TriforceConfig.Items
---@field enabled? boolean

---@class TriforceConfigDefaults.Items: TriforceConfig.Items
---@field enabled boolean

---Triforce setup configuration.
--- ---
---@class TriforceConfig
---List of user-defined achievements.
--- ---
---@field achievements? Achievement[]
---Auto-save stats interval in seconds (default: `300`).
--- ---
---@field auto_save_interval? integer
---Backdrop (i.e. dimming the background) options.
---
---CREDITS: https://github.com/gisketch/triforce.nvim/issues/50
--- ---
---@field backdrop? TriforceConfig.Backdrop
---Custom language definitions:
---
---```lua
----- Example
---{ rust = { icon = "", name = "Rust" } }
---```
--- ---
---@field custom_languages? table<string, TriforceLanguage>
---Custom path for data file.
--- ---
---@field db_path? string
---Enable debugging messages.
--- ---
---@field debug? boolean
---Enable the plugin.
--- ---
---@field enabled? boolean
---Enable gamification features (stats, XP, achievements).
--- ---
---@field gamification_enabled? boolean
---Default highlight groups for the heats.
--- ---
---@field heat_highlights? TriforceConfig.Heat
-- Select what icon engine to use to provide with filetype icons:
--
-- - `'builtin'` - Use the built-in icons (default)
-- - `'mini'` - Use `mini.icons`
-- ---
---@field icon_engine? TriforceIconEngine
---List of ignored filetypes.
--- ---
---@field ignore_ft? string[]
---@field items? TriforceConfig.Items
---List of custom level titles.
--- ---
---@field levels? LevelParams[]
---Custom level progression tiers.
--- ---
---@field level_progression? LevelProgression
---Notification configuration.
--- ---
---@field notifications? TriforceConfig.Notifications
---Allow users to override default levels.
--- ---
---@field override_levels? boolean
---Custom XP reward amounts for different actions.
--- ---
---@field xp_rewards? XPRewards

---@class TriforceConfigDefaults: TriforceConfig
---@field achievements Achievement[]
---@field auto_save_interval integer
---@field backdrop TriforceConfigDefaults.Backdrop
---@field custom_languages table<string, TriforceLanguage>
---@field db_path string
---@field debug boolean
---@field enabled boolean
---@field gamification_enabled boolean
---@field heat_highlights TriforceConfigDefaults.Heat
---@field icon_engine TriforceIconEngine
---@field ignore_ft string[]
---@field items TriforceConfigDefaults.Items
---@field level_progression LevelProgression
---@field levels LevelParams[]
---@field notifications TriforceConfigDefaults.Notifications
---@field override_levels boolean
---@field xp_rewards XPRewards

---@class Achievement
---@field desc? string
---@field icon? string
---@field id string
---@field name string
local A = {}

---The condition that decides whether an achievement is unlocked
---@param stats? Stats
---@return boolean unlocked
function A.check(stats) end

---@class TriforceLanguage
---@field icon string
---@field name string

---@class LevelTitle
---@field icon string
---@field title string

---@alias LevelTitles table<integer, LevelTitle>

---@class LevelParams
---@field icon? string
---@field level integer
---@field title string

---@class LevelSpec
---@field level integer
---@field title string
---@field unlocked boolean

---Non-legacy validation spec (>=v0.11)
---@class ValidateSpec
---@field [1] any
---@field [2] vim.validate.Validator
---@field [3]? boolean
---@field [4]? string

---@alias Months
---|1
---|2
---|3
---|4
---|5
---|6
---|7
---|8
---|9
---|10
---|11
---|12

-- vim: set ts=2 sts=2 sw=2 et ai si sta:
