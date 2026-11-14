# triforce.nvim

<a href="https://github.com/rockerBOO/awesome-neovim">
<img alt="Mentioned in Awesome Neovim" src="https://awesome.re/mentioned-badge.svg" />
</a>

> [!IMPORTANT]
> **_The original repository ([gisketch/triforce.nvim](https://github.com/gisketch/triforce.nvim)) is currently unavailable.
> Since I was the co-maintainer, [@gisketch](https://github.com/gisketch) authorized me to mirror it while his account is reinstated._**
>
> **_Read [this post](https://www.reddit.com/r/neovim/comments/1x696yi/triforcenvim_the_plugin_is_now_available_once/) for more information on the topic._**

**Hey, listen!** Triforce adds a bit of RPG flavor to your coding — XP, levels and achievements while you work.

<div align="center">
<img alt="Showcase" src="https://github.com/gisketch/triforce.nvim/blob/main/assets/triforce.png" />
</div>

---

## About

I named this plugin **Triforce** just because I love **The Legend of Zelda**.

I have ADHD (Attention Deficit Hyperactivity Disorder), which can make coding feel like a grind;
it’s hard to stay consistent or even get started some days. That’s part of why I fell in love with
Neovim: it’s customizable, expressive, and makes the act of writing code feel fun again.

Triforce is co-maintained by [@DrKJeff16](https://github.com/DrKJeff16), who has ADHD, too.

This is my first Neovim plugin (and the first plugin I’ve ever built in general). I’d always wanted
to make something of my own, but I never really knew where to start. Once I got into Neovim’s Lua
ecosystem I got completely hooked. I started experimenting, tinkering, breaking things, and slowly,
Triforce came to life.

This exists to **gamify my coding workflow**; to turn those long, sometimes frustrating coding
sessions into an experience that actually feels rewarding. Watching the XP bar fill up, unlocking
achievements, and seeing my progress in real time gives me that little dopamine boost to help me
stay focused and motivated.

The UI is **heavily inspired by [@siduck](https://github.com/siduck)’s gorgeous designs** and **[nvzone/typr](https://github.com/nvzone/typr)**; their aesthetic sense
and clean interface ideas played a huge role in how this turned out. Building it with [`nvzone/volt`](https://github.com/nvzone/volt)
made the process so much smoother and helped me focus on bringing those ideas to life.

---

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Configuration](#configuration)
  - [Custom Levels](#custom-levels)
  - [Level Progression](#level-progression)
  - [XP Rewards](#xp-rewards)
- [Usage](#usage)
- [Profile UI](#profile-ui)
  - [Achievements Tab](#achievements-tab)
  - [Languages Tab](#languages-tab)
  - [Levels Tab](#levels-tab)
  - [Stats Tab](#stats-tab)
- [Achievements](#achievements)
  - [Custom Achievements](#custom-achievements)
- [Customization](#customization)
  - [Adding Custom Languages](#adding-custom-languages)
  - [Disabling Notifications](#disabling-notifications)
  - [Custom Keymap](#custom-keymap)
  - [Customizing Heatmap Colors](#customizing-heatmap-colors)
- [Lualine Integration](#lualine-integration)
  - [Component Configuration](#component-configuration)
    - [Achievements Component](#achievements-component)
    - [Currency Component](#currency-component)
    - [Level Component](#level-component)
    - [Session Time Component](#session-time-component)
    - [Streak Component](#streak-component)
- [Data Storage](#data-storage)
  - [Exporting](#exporting)
- [Roadmap](#roadmap)
- [Acknowledgments](#acknowledgments)
- [License](#license)

---

## Features

- **Active Support** - Triforce is actively maintained, and reported bugs are quickly addressed
- **Detailed Statistics** - Track lines typed, characters, sessions, coding time, and more
- **Gamification** - Earn XP and level up based on your coding activity
- **Achievements** - Unlock achievements for milestones (first 1000 chars, 10 sessions, etc.)
- **Activity Heatmap** - GitHub-style contribution graph showing your coding consistency
- **Language Tracking** - See which programming languages you use most
- **Beautiful UI** - Clean, themed interface powered by [nvzone/volt](https://github.com/nvzone/volt)
- **Lualine Integration** - Optional modular [lualine components](#lualine-integration)
- **Highly Configurable** - Customize notifications and keymaps, add custom languages, levels and achievements
- **Auto-Save** - Your progress is automatically saved every 5 minutes
- **Documented Code** - The code is thoroughly documented and annotated with LuaLS annotations
- **(EXPERIMENTAL) Currency and Items** - Gain currency alongside XP to buy items. Try running `:Triforce items <TAB>`

---

## Installation

**Requirements:**

- [Neovim](https://github.com/neovim/neovim) >=v0.10.0
- [nvzone/volt](https://github.com/nvzone/volt) - UI framework dependency
- A [patched font](https://www.nerdfonts.com/) - For icons
  - [mini.icons](https://github.com/nvim-mini/mini.icons) **(OPTIONAL)**

<details>
<summary>lazy.nvim</summary>

```lua
{
  'gisketch/triforce.nvim',
  dependencies = { 'nvzone/volt' },
  keys = {
    {
      '<leader>tp',
      function()
        require('triforce').show_profile()
      end,
    },
  },
  opts = {},
}
```

</details>
<details>
<summary><code>vim.pack</code></summary>

```lua
vim.pack.add({
  { src = 'https://github.com/nvzone/volt' },
  { src = 'https://github.com/gisketch/triforce.nvim' },
})
```

</details>
<details>
<summary>pckr.nvim</summary>

```lua
require('pckr').add({
  {
    'gisketch/triforce.nvim',
    requires = { 'nvzone/volt' },
    config = function()
      require('triforce').setup()
    end
  }
})
```

</details>
<details>
<summary>paq-nvim</summary>

```lua
require('paq')({
  'nvzone/volt',
  'gisketch/triforce.nvim',
})

require('triforce').setup()
```

</details>
<details>
<summary>vim-plug</summary>

```vim
Plug 'gisketch/triforce.nvim' | Plug 'nvzone/volt'

lua << EOF
require('triforce').setup()
EOF
```

</details>

---

## Configuration

You can simply call `setup()` and the defaults will be loaded:

```lua
require('triforce').setup()
```

| Field                  | Type          | Default Value                                              | Description                                |
|------------------------|---------------|------------------------------------------------------------|--------------------------------------------|
| `achievements`         | `table\|nil`  | See [Custom Achievements](#custom-achievements)            | Custom achievements                        |
| `auto_save_interval`   | `number`      | `300`                                                      | Auto-save interval in seconds              |
| `backdrop`             | `table\|nil`  | `{ enabled = true, winblend = 20 }`                        | List of excluded filetypes                 |
| `custom_languages`     | `table\|nil`  | `nil`                                                      | Custom language definitions                |
| `debug`                | `boolean`     | `true`                                                     | Enable some debugging messages             |
| `enabled`              | `boolean`     | `true`                                                     | Enable/disable the plugin                  |
| `gamification_enabled` | `boolean`     | `true`                                                     | Enable gamification features               |
| `heat_highlights`      | `table\|nil`  | Defaults shown below                                       | Override heatmap highlights (hex or links) |
| `ignore_ft`            | `table\|nil`  | `{}`                                                       | Backdrop customization                     |
| `items`                | `table\|nil`  | `{ enabled = false }`                                      | Items configuration                        |
| `level_progression`    | `table\|nil`  | See [Level Progression](#level-progression)                | Custom XP requirements per level tier      |
| `levels`               | `table\|nil`  | See [Custom Levels](#custom-levels)                        | List of custom levels                      |
| `notifications`        | `table\|nil`  | `{ achievements = true, enabled = true, level_up = true }` | Notifications for different events |
| `override_levels`      | `boolean`     | `false`                                                    | Don't include the built-in levels          |
| `xp_rewards`           | `table\|nil`  | [See below](#xp-rewards)                                   | Custom XP rewards for actions              |

<details>
<summary><b><ins>Defaults</ins></b></summary>

You can find the defaults in [`lua/triforce/config.lua`](https://github.com/gisketch/triforce.nvim/blob/main/lua/triforce/config.lua):

```lua
require('triforce').setup({
  -- Enable/disable the entire plugin
  enabled = true,

  -- Select what icon engine to use to provide with filetype icons:
  --
  -- - `'builtin'` - Use the built-in icons (default)
  -- - `'mini'` - Use `mini.icons`
  icon_engine = 'builtin',

  -- Enable XP, levels, achievements and optionally items
  gamification_enabled = true,

  -- Items configuration (EXPERIMENTAL)
  items = {
    -- Enable items (requires `gamification_enabled`)
    enabled = false,
  },

  -- Backdrop control
  backdrop = {
    -- Whether to enable the backdrop (i.e. enable background dimming).
    -- CREDITS: https://github.com/gisketch/triforce.nvim/issues/50
    enabled = true,

    -- See `:h 'winblend'`
    winblend = 20,
  },

  -- Custom levels (requires `override_levels`)
  levels = {},

  -- Don't include the default levels
  override_levels = false,

  -- Custom achievements
  achievements = {},

  -- Notification settings
  notifications = {
    -- Show achievement unlock notifications
    achievements = true,

    -- Master toggle for all notifications
    enabled = true,

    -- Show level up notifications
    level_up = true,
  },

  -- Auto-save interval (in seconds)
  auto_save_interval = 300, -- Save stats every 5 minutes

  -- Add custom language support
  custom_languages = {
    gleam = { icon = '✨', name = 'Gleam' }, -- `icon` is optional!
    odin = { icon = '🔷', name = 'Odin' },
    -- Add more languages...
  },

  -- Customize level progression (optional)
  level_progression = {
    tier_1 = { min_level = 1, max_level = 10, xp_per_level = 500 },
    tier_2 = { min_level = 11, max_level = 20, xp_per_level = 750 },
    tier_3 = { min_level = 21, max_level = 30, xp_per_level = 1250 },
    tier_4 = { min_level = 31, max_level = 40, xp_per_level = 2500 },
    tier_5 = { min_level = 41, max_level = 50, xp_per_level = 3750 },
    tier_6 = { min_level = 51, max_level = 75, xp_per_level = 5000 },
    tier_7 = { min_level = 76, max_level = 100, xp_per_level = 10000 },
    tier_8 = { min_level = 101, max_level = 150, xp_per_level = 12500 },
    tier_9 = { min_level = 151, max_level = 225, xp_per_level = 15000 },
    tier_10 = { min_level = 226, max_level = math.huge, xp_per_level = 25000 }, -- `max_level` here MUST be `math.huge`!
  },

  -- Customize XP rewards (optional)
  xp_rewards = {
    -- XP per character typed
    char = 1,

    -- XP per new line
    line = 1,

    -- XP per file save
    save = 50,
  },

  -- Add filetypes to be excluded
  ignore_ft = {},

  -- Override heatmap highlight groups (hex colors or existing hl groups)
  heat_highlights = {
    TriforceHeat0 = '#f0f0f0',
    TriforceHeat1 = '#f0f0a0',
    TriforceHeat2 = '#f0a0a0',
    TriforceHeat3 = '#a0a0a0',
    TriforceHeat4 = '#707070',
    -- Or link to your colorscheme's groups:
    -- TriforceHeat1 = 'DiffText',
  },

  -- Enable some debugging messages
  debug = false,
})
```

</details>

### Custom Levels

By default, Triforce provides a Zelda-themed set of levels with title and icons:

```lua
{
  [10] = { title = 'Deku Scrub', icon = '🌱' },
  [20] = { title = 'Kokiri', icon = '🌳' },
  [30] = { title = 'Hylian Soldier', icon = '🗡️' },
  [40] = { title = 'Knight', icon = '⚔️' },
  [50] = { title = 'Royal Guard', icon = '🛡️' },
  [60] = { title = 'Master Swordsman', icon = '⚡' },
  [70] = { title = 'Hero of Time', icon = '🔺' },
  [80] = { title = 'Sage', icon = '✨' },
  [90] = { title = 'Triforce Bearer', icon = '🔱' },
  [100] = { title = 'Champion', icon = '👑' },
  [120] = { title = 'Divine Beast Pilot', icon = '🦅' },
  [150] = { title = 'Ancient Hero', icon = '🏛️' },
  [180] = { title = 'Legendary Warrior', icon = '⚜️' },
  [200] = { title = 'Goddess Chosen', icon = '🌟' },
  [250] = { title = 'Demise Slayer', icon = '💀' },
  [300] = { title = 'Eternal Legend', icon = '💫' },
}
```

You can add custom levels in your config aswell:

```lua
require('triforce').setup({
  levels = {
    { level = 5, title = 'Newbie', icon = '🌱' },
    { level = 25, title = 'Charmful Coder' } -- The `icon` field is optional, which will become an empty string if unset
  },
})
```

### Level Progression

Triforce by default uses a **simple, easy-to-reach** leveling system.

The default leveling system is as follows:

- **Levels 1-10**: 500 XP per level
- **Levels 11-20**: 750 XP per level
- **Levels 21-30**: 1,250 XP per level
- **Levels 31-40**: 2,500 XP per level
- **Levels 41-50**: 3,750 XP per level
- **Levels 51-75**: 5,000 XP per level
- **Levels 76-100**: 10,000 XP per level
- **Levels 101-150**: 12,500 XP per level
- **Levels 151-225**: 15,000 XP per level
- **Levels +226**: 25,000 XP per level

Example progression:

- **Level 5**: 1,500 XP (`5 × 300`)
- **Level 10**: 3,000 XP (`10 × 300`)
- **Level 15**: 5,500 XP (`3,000 + 5 × 500`)
- **Level 20**: 8,000 XP (`3,000 + 10 × 500`)
- **Level 30**: 18,000 XP (`8,000 + 10 × 1,000`)

You can customize this by overriding `level_progression` in your setup.
The defaults are:

```lua
require('triforce').setup({
  level_progression = {
    tier_1 = { min_level = 1, max_level = 10, xp_per_level = 500 },
    tier_2 = { min_level = 11, max_level = 20, xp_per_level = 750 },
    tier_3 = { min_level = 21, max_level = 30, xp_per_level = 1250 },
    tier_4 = { min_level = 31, max_level = 40, xp_per_level = 2500 },
    tier_5 = { min_level = 41, max_level = 50, xp_per_level = 3750 },
    tier_6 = { min_level = 51, max_level = 75, xp_per_level = 5000 },
    tier_7 = { min_level = 76, max_level = 100, xp_per_level = 10000 },
    tier_8 = { min_level = 101, max_level = 150, xp_per_level = 12500 },
    tier_9 = { min_level = 151, max_level = 225, xp_per_level = 15000 },
    tier_10 = { min_level = 226, max_level = math.huge, xp_per_level = 25000 },
  },
})
```

### XP Rewards

By default, Triforce awards XP for different coding activities:

- **Character typed**: 1 XP
- **New line**: 1 XP
- **File save**: 10 XP

You can customize these values to match your preferences. For example, if you want to emphasize
quality over quantity and reward saves more:

```lua
require('triforce').setup({
  xp_rewards = {
    char = 0.5, -- Less XP for characters
    line = 2,   -- More XP for new lines
    save = 10,  -- Reward file saves heavily
  },
})
```

Or if you prefer to focus on typing volume:

```lua
require('triforce').setup({
  xp_rewards = {
    char = 2, -- More XP per character
    line = 3, -- Moderate XP for lines
    save = 5, -- Less emphasis on saves
  },
})
```

---

## Usage

Triforce creates the `:Triforce` user command for your comfort. Here are the available arguments:

| Command                                                        | Description                                                                                                                                              |
|----------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------|
| `:Triforce config`                                             | Open floating window showing your setup config                                                                                                           |
| `:Triforce debug languages`                                    | Debug language tracking                                                                                                                                  |
| `:Triforce profile`                                            | Toggles the Profile UI.                                                                                                                                  |
| `:Triforce profile stats\|achievements\|languages\|levels`     | Toggles/cycles the Profile UI. If the UI is open and the passed tab is not the same as the current, it will cycle to it                                  |
| `:Triforce reset`                                              | Reset all stats (useful for testing)                                                                                                                     |
| `:Triforce stats`                                              | Display current stats in a notification                                                                                                                  |
| `:Triforce stats export`                                       | Export stats to a new buffer                                                                                                                             |
| `:Triforce stats export json [</path/to/file> [INDENT_LEVEL]]` | Export stats to JSON format. If a file name is given, the exported data will be saved there, otherwise a new buffer will open with the exported data     |
| `:Triforce stats export lua [</path/to/file>]`                 | Export stats to Lua format. If a file name is given, the exported data will be saved there, otherwise a new buffer will open with the exported data      |
| `:Triforce stats export markdown [</path/to/file>]`            | Export stats to Markdown format. If a file name is given, the exported data will be saved there, otherwise a new buffer will open with the exported data |
| `:Triforce stats save`                                         | Force-save stats immediately                                                                                                                             |

---

## Profile UI

The profile UI includes the following tabs:

- [Achievements](#achievements-tab)
- [Languages](#languages-tab)
- [Levels](#levels-tab)
- [Stats](#stats-tab)

The following keybindings can be used in the profile UI:

| Key(s)                            | Description                                            |
|-----------------------------------|--------------------------------------------------------|
| `<Tab>` / `<S-Tab>`               | Cycle tab (forward or backward, respectively)          |
| `H` / `L` or `<Left>` / `<Right>` | Navigate between items for the achievements/levels tab |
| `q` / `<Esc>`                     | Close profile UI                                       |

### Achievements Tab

<div align="center">
<img alt="Achievements Tab" src="https://github.com/gisketch/triforce.nvim/blob/main/assets/triforce_achievements.png" />
</div>

- View all unlocked achievements and locked achievements with unlock requirements
- Paginate through achievements (`H` / `L` or arrow keys)
- Directly accessible through `:Triforce profile achievements`

### Languages Tab

<div align="center">
<img alt="Languages Tab" src="https://github.com/gisketch/triforce.nvim/blob/main/assets/triforce_languages.png" />
</div>

- Bar graph showing your most-used languages
- See character count breakdown by language
- Directly accessible through `:Triforce profile languages`

### Levels Tab

<div align="center">
<img alt="Levels Tab" src="https://github.com/gisketch/triforce.nvim/blob/main/assets/triforce_levels.png" />
</div>

- View unlocked levels first, then locked ones
- Paginate through achievements (`H` / `L` or arrow keys)
- Directly accessible through `:Triforce profile levels`

### Stats Tab

<div align="center">
<img alt="Stats Tab" src="https://github.com/gisketch/triforce.nvim/blob/main/assets/triforce_stats.png" />
</div>

- Level progress bar
- Session/time milestone progress
- Activity heatmap (7 months)
- Quick stats overview
- Directly accessible through `:Triforce profile stats`

---

## Achievements

Triforce includes **18 built-in achievements** across 5 categories:

- **Level Achievements:**

| Achievement Name    | Completion Requirement(s) |
|---------------------|---------------------------|
| ⭐ **Rising Star**  | Reach level 5             |
| 💎 **Expert Coder** | Reach level 10            |
| 👑 **Champion**     | Reach level 25            |
| 🔱 **Legend**       | Reach level 50            |

- **Polyglot Achievements:**

| Achievement Name         | Completion Requirement(s)      |
|--------------------------|--------------------------------|
| 🌍 **Polyglot Beginner** | Code in 3 different languages  |
| 🌎 **Polyglot**          | Code in 5 different languages  |
| 🌏 **Master Polyglot**   | Code in 10 different languages |
| 🗺️ **Language Virtuoso** | Code in 15 different languages |

- **Session Achievements:**

| Achievement Name         | Completion Requirement(s) |
|--------------------------|---------------------------|
| 🔄 **Regular Visitor**   | Complete 10 sessions      |
| 📅 **Creature of Habit** | Complete 50 sessions      |
| 🏆 **Dedicated Hero**    | Complete 100 sessions     |

- **Time Achievements:**

| Achievement Name  | Completion Requirement(s) |
|-------------------|---------------------------|
| ⏰ **First Hour** | Code for 1 hour total     |
| ⌛ **Committed**  | Code for 10 hours total   |
| 🕐 **Veteran**    | Code for 100 hours total  |

- **Typing Achievements:**

| Achievement Name       | Completion Requirement(s) |
|------------------------|---------------------------|
| 🌱 **First Steps**     | Type 100 characters       |
| ⚔️ **Getting Started** | Type 1,000 characters     |
| 🛡️ **Dedicated Coder** | Type 10,000 characters    |
| 📜 **Master Scribe**   | Type 100,000 characters   |

### Custom Achievements

Triforce now allows you to create new achievements with the `achievements` setup option.
**By default it's just an empty table.**

The `Achievement` type spec is shown below:

```lua
---@class Stats
---@field achievements table<string, boolean>
---@field chars_by_language table<string, integer>
---@field chars_typed integer
---@field currency integer
---@field current_streak integer
---@field daily_activity table<string, integer>
---@field db_path string
---@field last_session_start integer
---@field level integer
---@field lines_typed integer
---@field longest_streak integer
---@field sessions integer
---@field time_coding integer
---@field xp number

-- DO NOT COPY DIRECTLY
{
  ---@param stats? Stats
  ---@return boolean ok
  check = function(stats)
    return stats.foo > stats.bar -- NOTE: This is just an example
  end,
  desc = '...' or nil, ---@type string|nil|?
  icon = '...' or nil, ---@type string|nil|?
  id = 'template_achievement', ---@type string
  name = '...', ---@type string
}
```

Example:

```lua
require('triforce').setup({
  achievements = {
    {
      check = function(stats)
        return stats.chars_typed >= 200
      end,
      desc = 'Type 200 Characters',
      id = 'first_200',
      name = 'On Track',
    },
    {
      check = function(stats)
        return stats.chars_typed >= 300
      end,
      desc = 'Type 300 Characters',
      id = 'first_300',
      name = 'Newbie',
    },
    {
      check = function(stats)
        return stats.level >= 100
      end,
      desc = 'Reach level 100',
      icon = '󰈸',
      id = 'level_100',
      name = 'God-Like',
    },
  },
})
```

---

## Customization

### Adding Custom Languages

More than 50 programming languages are natively supported, but you can add more if you wish:

```lua
require('triforce').setup({
  custom_languages = {
    gleam = { icon = '✨', name = 'Gleam' },
    zig = { icon = '⚡', name = 'Zig' },
  },
})
```

### Disabling Notifications

To turn off notifications, simply disable them on setup:

```lua
require('triforce').setup({
  notifications = {
    level_up = false, -- Disable level up notifications
  },
})
```

### Custom Keymap

You can set your own keymap to open Triforce's UI:

```lua
-- THIS IS AN EXAMPLE, SET YOUR OWN KEYMAP
vim.keymap.set('n', '<C-s>', require('triforce').show_profile, { desc = 'Show Triforce Stats' })
```

### Customizing Heatmap Colors

If your colorscheme uses unconventional highlight groups, point the heatmap-to-colors that fit
your palette the best. You can use hex colors and/or links to existing highlight groups:

```lua
require('triforce').setup({
  heat_highlights = {
    TriforceHeat0 = nil, -- Will revert back to default
    TriforceHeat1 = 'Error',
    TriforceHeat2 = 'DiagnosticVirtualTextWarn',
    TriforceHeat3 = 'CursorLine',
    TriforceHeat4 = '#424242',
  },
})
```

Each key corresponds to a heat level used in the profile activity graph. If a key is omitted or
set to `nil` then it will revert back to its default value.

---

## Lualine Integration

<div align="center">
<img alt="Lualine Integration" src="https://github.com/gisketch/triforce.nvim/blob/main/assets/triforce_lualine.png" />
</div>

Triforce comes with **modular statusline components** for [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim), letting you display your
coding stats right in your statusline.

You can add the default Triforce component to your lualine config:

```lua
require('lualine').setup({
  sections = {
    lualine_x = { 'triforce' },
  }
})
```

### Component Configuration

Each component can be customized independently.

The following `lualine` components are available (**a patched font is required**):

| Component                                 | Default Display | Enabled by Default? | Description                   |
|-------------------------------------------|-----------------|---------------------|-------------------------------|
| [`achievements`](#achievements-component) | `🏆 12/18`      |                    | Unlocked/total achievements   |
| [`currency`](#currency-component)         | `💰 484`        |                    | Current amount of currency    |
| [`level`](#level-component)               | `Lv.27 ████░░`  |                    | Level + XP progress bar       |
| [`session_time`](#session-time-component) | `⏰ 2h 34m`     |                    | Current session duration      |
| [`streak`](#streak-component)             | `🔥 5`          |                    | Current coding streak in days |

<details>
<summary><b><ins></ins>Default setup options</b></summary>

```lua
require('lualine').setup({
  sections = {
    lualine_x = {
      {
        'triforce',
        achievements = {
          enabled = false,
          icon = '',
          show_count = true,
        },
        currency = {
          enabled = true,
          prefix = '💰',
        },
        level = {
          bar = { chars = { empty = '░', filled = '█' }, length = 6 },
          enabled = true,
          prefix = 'Lv.',
          show = { bar = true, level = true, percent = false, xp = false },
        },
        session_time = {
          enabled = false,
          icon = '',
          show_duration = true,
          format = 'short',
        },
        streak = {
          enabled = false,
          icon = '',
          show_days = true,
        },
      },
    },
  }
})
```

</details>

#### Achievements Component

Options:

- `enabled` (boolean): Activates this component (default: `false`)
- `icon` (string): Icon to display (default: `'🏆'`)
- `show_count` (boolean): Show unlocked/total count (default: `true`)

```lua
require('lualine').setup({
  sections = {
    lualine_x = {
      { 'triforce', achievements = { enabled = false, icon = '🏆', show_count = true } },
    },
  }
})
```

#### Currency Component

Options:

- `enabled` (boolean): Activates this component (default: `true`)
- `prefix` (string): The prefix before the amount of currency (default: `'💰'`)

```lua
require('lualine').setup({
  sections = {
    lualine_x = {
      { 'triforce', currency = { enabled = true, prefix = '💰' } },
    },
  }
})
```

#### Level Component

Options:

- `bar` (table): Bar properties:
  - `chars` (table): Signal both char types (`empty` and `filled`) for the bar (default: `{ empty = '░', filled = '█' }`)
  - `length` (number): Progress bar length (default: `6`)
- `enabled` (boolean): Activates this component (default: `true`)
- `prefix` (string): Text prefix before level number (default: `'Lv.'`)
- `show` (table): Toggles for showing different components:
  - `bar` (boolean): Show progress bar (default: `true`)
  - `level` (boolean): Show level number (default: `true`)
  - `percent` (boolean): Show percentage (default: `false`)
  - `xp` (boolean): Show XP numbers like `450/500` (default: `false`)

```lua
require('lualine').setup({
  sections = {
    lualine_x = {
      {
        'triforce',
        level = {
          bar = { chars = { filled = '█', empty = '░' }, length = 6 },
          enabled = true,
          prefix = 'Lv.',
          show = { bar = true, level = true, percent = false, xp = false },
        },
      },
    },
  }
})
```

#### Session Time Component

Options:

- `enabled` (boolean): Activates this component (default: `false`)
- `format` (string): `'short'` (2h 34m) or `'long'` (2:34:12) (default: `'short'`)
- `icon` (string): Icon to display (default: `''` - clock)
- `show_duration` (boolean): Show time duration (default: `true`)

```lua
require('lualine').setup({
  sections = {
    lualine_x = {
      {
        'triforce',
        session_time = { enabled = false, icon = '', show_duration = true, format = 'short' },
      },
    },
  }
})
```

#### Streak Component

Options:

- `enabled` (boolean): Activates this component (default: `false`)
- `icon` (string): Icon to display (default: `''` - flame)
- `show_days` (boolean): Show day count (default: `true`)

The streak component returns an empty string when streak is 0, so it won't clutter your statusline.

```lua
require('lualine').setup({
  sections = {
    lualine_x = {
      {
        'triforce',
        streak = { enabled = false, icon = '', show_days = true },
      },
    },
  }
})
```

---

## Data Storage

By default, stats are saved to `~/.local/share/nvim/triforce_stats.json`. A backup is automatically
created before each save to `~/.local/share/nvim/triforce_stats.json.bak`.

### Exporting

You can export your stats with the `:Triforce stats export` command.

<details>
<summary><b><ins>Example output</ins></b></summary>

The following is an export output in JSON format:

```json
{
  "achievements": {
    "first_100": true,
    "first_1000": true,
    "first_10000": true,
    "first_100000": true,
    "first_300": true,
    "first_session": true,
    "level_10": true,
    "level_25": true,
    "level_5": true,
    "level_50": true,
    "polyglot_3": true,
    "polyglot_5": true,
    "sessions_10": true,
    "sessions_100": true,
    "sessions_50": true,
    "time_10h": true,
    "time_1h": true
  },
  "chars_by_language": {
    "bash": 3068,
    "c": 3389,
    "lua": 119157,
    "org": 14,
    "python": 3189,
    "sh": 580
  },
  "chars_typed": 158384,
  "currency": 26066,
  "current_streak": 2,
  "daily_activity": {
    "2026-09-19": 55,
    "2026-09-20": 342,
    "2026-09-21": 162,
    "2026-09-22": 864,
    "2026-09-23": 326,
    "2026-09-24": 381,
    "2026-09-25": 807,
    "2026-09-26": 642,
    "2026-09-27": 548,
    "2026-09-28": 208,
    "2026-09-29": 506,
    "2026-09-30": 325,
    "2026-10-01": 379,
    "2026-10-02": 826,
    "2026-10-03": 224,
    "2026-10-04": 308,
    "2026-10-05": 188,
    "2026-10-06": 216,
    "2026-10-07": 77,
    "2026-10-08": 104,
    "2026-10-09": 321,
    "2026-10-10": 245,
    "2026-10-11": 4,
    "2026-10-13": 592,
    "2026-10-14": 104
  },
  "db_path": "/home/<YOUR_USERNAME>/.local/share/nvim/triforce_stats.json",
  "last_session_start": 1792037375,
  "level": 71,
  "lines_typed": 8833,
  "longest_streak": 23,
  "sessions": 1974,
  "time_coding": 167848,
  "xp": 190536
}
```

</details>

The following user command operations are available:

| Command                                               | Format   | Description                                                                                                                      |
|-------------------------------------------------------|----------|----------------------------------------------------------------------------------------------------------------------------------|
| `:Triforce stats export`                              | Lua      | Raw export of your stats in a new buffer                                                                                         |
| `:Triforce stats export json [<PATH> [INDENT_LEVEL]]` | JSON     | Export your stats to a given JSON file (with optional indent). If no path is given, the stats will be exported in another buffer |
| `:Triforce stats export lua [<PATH>]`                 | Lua      | Export your to a given Lua file, with custom formatting. If no path is given, the stats will be exported in another buffer       |
| `:Triforce stats export markdown [<PATH>]`            | Markdown | Export your to a given Markdown file, with custom formatting. If no path is given, the stats will be exported in another buffer  |

---

## Roadmap

- [ ] **VCS Support**: Allow individual tracking per Git branch/tag.
- [ ] **Sounds for Achievements and Level up**: Add SFX feedback for leveling up
  or completing achievements for dopamine!
- [ ] **Cloud Sync**: Sync stats across multiple devices (Firebase, GitHub Gist, or custom server)
- [ ] **Leaderboards**: Compete with friends or the community
- [X] **Exclude by Filetype**: Add filetypes you don't want to track
- [X] **Custom Achievements**: Define your own achievement criteria
- [X] **Currency and Items**: Add currency to enable buying certain items (`:Triforce items ...`)
- [X] **Export Stats**: Export to JSON or Markdown reports
- [ ] **Weekly/Monthly Reports**: Automated summaries via notifications
- [ ] **Themes**: Customizable color schemes for the profile UI
- [ ] **Plugin API**: Expose hooks for other plugins to integrate

**Have a feature idea?** Open an issue on GitHub!

---

## Acknowledgments

- [`nvzone/volt`](https://github.com/nvzone/volt): Beautiful UI framework
- [`nvzone/typr`](https://github.com/nvzone/typr): Beautiful grid design component inspiration
- [`GrzegorzSzczepanek/gamify.nvim`](https://github.com/GrzegorzSzczepanek/gamify.nvim): Another cool gamification plugin, inspired the inclusion of achievements

---

## License

[MIT](https://github.com/gisketch/triforce.nvim/blob/main/LICENSE)
<!-- vim: set ts=2 sts=2 sw=2 et ai si sta: -->
