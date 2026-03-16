# triforce.nvim

[![Mentioned in Awesome Neovim](https://awesome.re/mentioned-badge.svg)](https://github.com/rockerBOO/awesome-neovim)

[Share Your Stats](https://github.com/gisketch/triforce.nvim/discussions/30)

**Hey, listen!** Triforce adds a bit of RPG flavor to your coding — XP, levels and achievements
while you work.

![Showcase](./assets/triforce.png)

---

## About

I have ADHD, which sometimes causes coding to feel like a grind — it’s hard to stay consistent
or even get started some days.
That’s part of why I fell in love with Neovim: it’s customizable, expressive,
and makes the act of writing code feel _fun_ again.

**Triforce** is actually my **first-ever Neovim plugin** (and the first plugin I’ve ever built in general).
I’d always wanted to make something of my own, but I never really knew where to start.
Once I got into Neovim’s Lua ecosystem I got completely hooked.
I started experimenting, tinkering, breaking things, and slowly, Triforce came to life.

Triforce is co-maintained by [@DrKJeff16](https://github.com/DrKJeff16), who has ADHD, too.

I made it to **gamify my coding workflow** — to turn those long,
sometimes frustrating coding sessions into something that feels rewarding.
Watching the XP bar fill up, unlocking achievements, and seeing my progress in real time
gives me that little _dopamine boost_ that helps me stay focused and motivated.

I named it **Triforce** just because I love **The Legend of Zelda** — _no deep reason beyond that_.

The UI is **heavily inspired by [@siduck](https://github.com/siduck)’s gorgeous designs**
and **[nvzone/typr](https://github.com/nvzone/typr)** — their aesthetic sense and clean interface ideas
played a huge role in how this turned out.
Building it with [`nvzone/volt`](https://github.com/nvzone/volt) made the process
so much smoother and helped me focus on bringing those ideas to life.

---

## Features

- **Active Support** - Triforce is actively maintained, and reported bugs are quickly addressed
- **Detailed Statistics** - Track lines typed, characters, sessions, coding time, and more
- **Gamification** - Earn XP and level up based on your coding activity
- **Achievements** - Unlock achievements for milestones (first 1000 chars, 10 sessions, etc.)
- **Activity Heatmap** - GitHub-style contribution graph showing your coding consistency
- **Language Tracking** - See which programming languages you use most
- **Beautiful UI** - Clean, themed interface powered by [nvzone/volt](https://github.com/nvzone/volt)
- **Lualine Integration** - Optional modular statusline components
  (see [Lualine Integration](#lualine-integration))
- **Highly Configurable** - Customize notifications and keymaps, add custom languages, levels
  and achievements
- **Auto-Save** - Your progress is automatically saved every 5 minutes
- **Documented Code** - The code is thoroughly documented and annotated with LuaLS annotations.

---

## Table of Contents

- [Installation](#installation)
  - [`lazy.nvim`](#lazynvim)
  - [`pckr.nvim`](#pckrnvim)
  - [`paq-nvim`](#paq-nvim)
  - [`vim-plug`](#vim-plug)
- [Configuration](#configuration)
  - [Configuration Options](#configuration-options)
  - [Custom Levels](#custom-levels)
  - [Level Progression](#level-progression)
  - [XP Rewards](#xp-rewards)
- [Usage](#usage)
- [Profile UI](#profile-ui)
  - [Stats Tab](#stats-tab)
  - [Achievements Tab](#achievements-tab)
  - [Stats Tab](#languages-tab)
  - [Levels Tab](#levels-tab)
- [Achievements](#achievements)
  - [Typing Milestones](#typing-milestones)
  - [Level Achievements](#level-achievements)
  - [Session Achievements](#session-achievements)
  - [Time Achievements](#time-achievements)
  - [Polyglot Achievements](#polyglot-achievements)
  - [Custom Achievements](#custom-achievements)
- [Customization](#customization)
  - [Adding Custom Languages](#adding-custom-languages)
  - [Disabling Notifications](#disabling-notifications)
  - [Disabling Auto-Keymap](#disabling-auto-keymap)
  - [Customizing Heatmap Colors](#customizing-heatmap-colors)
- [Lualine Integration](#lualine-integration)
  - [Basic Setup](#basic-setup)
  - [Quick Setup](#quick-setup)
  - [Component Configuration](#component-configuration)
    - [Level Component](#level-component)
    - [Achievements Component](#achievements-component)
    - [Streak Component](#streak-component)
    - [Session Time Component](#session-time-component)
  - [Global Component Configuration](#global-component-configuration)
  - [Example Configurations](#example-configurations)
    - [Minimalist Setup](#minimalist-setup)
    - [Full Stats Dashboard](#full-stats-dashboard)
    - [Custom Style](#custom-style)
- [Data Storage](#data-storage)
  - [Exporting](#exporting)
  - [Data Format](#data-format)
- [Roadmap](#roadmap)
- [Acknowledgments](#acknowledgments)
- [License](#license)

---

## Installation

Triforce has the following requirements:

- [Neovim](https://github.com/neovim/neovim) >=v0.9.0
- [`nvzone/volt`](https://github.com/nvzone/volt) - UI framework dependency
- A [patched font](https://www.nerdfonts.com/) - For icons

### `lazy.nvim`

```lua
{
  'gisketch/triforce.nvim',
  dependencies = { 'nvzone/volt' },
  opts = {},
}
```

### `pckr.nvim`

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

### `paq-nvim`

```lua
require('paq')({
  'nvzone/volt',
  'gisketch/triforce.nvim',
})
```


### `vim-plug`

```vim
Plug 'nvzone/volt'
Plug 'gisketch/triforce.nvim'
```

---

## Configuration

Triforce comes with sensible defaults, but you can customize everything:

<details>
<summary><b>Defaults</b></summary>

```lua
require('triforce').setup({
  enabled = true,              -- Enable/disable the entire plugin
  gamification_enabled = true, -- Enable XP, levels, achievements

  -- Custom levels
  levels = {},

  -- Custom achievements
  achievements = {},

  -- Notification settings
  notifications = {
    enabled = true,       -- Master toggle for all notifications
    level_up = true,      -- Show level up notifications
    achievements = true,  -- Show achievement unlock notifications
  },

  -- Keymap configuration
  keymap = {
    show_profile = '<leader>tp', -- Set to nil to disable default keymap
  },

  -- Auto-save interval (in seconds)
  auto_save_interval = 300, -- Save stats every 5 minutes

  -- Add custom language support
  custom_languages = {
    gleam = { icon = '✨', name = 'Gleam' },
    odin = { icon = '🔷', name = 'Odin' },
    -- Add more languages...
  },

  -- Customize level progression (optional)
  level_progression = {
    tier_1 = { min_level = 1, max_level = 10, xp_per_level = 300 },   -- Levels 1-10
    tier_2 = { min_level = 11, max_level = 20, xp_per_level = 500 },  -- Levels 11-20
    tier_3 = { min_level = 21, max_level = math.huge, xp_per_level = 1000 }, -- Levels 21+
  },

  -- Customize XP rewards (optional)
  xp_rewards = {
    char = 1,   -- XP per character typed
    line = 1,   -- XP per new line
    save = 50,  -- XP per file save
  },

  -- Add filetypes to be excluded
  ignore_ft = {},

  -- Override heatmap highlight groups (hex colors or existing hl groups)
  heat_highlights = {
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

### Configuration Options

| Option                       | Type          | Default                           | Description                                |
|------------------------------|---------------|-----------------------------------|--------------------------------------------|
| `enabled`                    | `boolean`     | `true`                            | Enable/disable the plugin                  |
| `gamification_enabled`       | `boolean`     | `true`                            | Enable gamification features               |
| `notifications.enabled`      | `boolean`     | `true`                            | Master toggle for notifications            |
| `notifications.level_up`     | `boolean`     | `true`                            | Show level up notifications                |
| `notifications.achievements` | `boolean`     | `true`                            | Show achievement notifications             |
| `debug`                      | `boolean`     | `true`                            | Enable some debugging messages             |
| `auto_save_interval`         | `number`      | `300`                             | Auto-save interval in seconds              |
| `keymap.show_profile`        | `string\|nil` | `nil`                             | Keymap for opening profile                 |
| `custom_languages`           | `table\|nil`  | `nil`                             | Custom language definitions                |
| `ignore_ft`                  | `table\|nil`  | `{}`                              | List of excluded filetypes                 |
| `levels`                     | `table\|nil`  | [See below](#custom-levels)       | List of custom levels                      |
| `level_progression`          | `table\|nil`  | [See below](#level-progression)   | Custom XP requirements per level tier      |
| `xp_rewards`                 | `table\|nil`  | [See below](#xp-rewards)          | Custom XP rewards for actions              |
| `achievements`               | `table\|nil`  | [See below](#custom-achievements) | Custom achievements                        |
| `heat_highlights`            | `table\|nil`  | Defaults shown above              | Override heatmap highlights (hex or links) |

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
    { level = 25, title = 'Charmful Coder' } -- You can omit your icon (will be left empty)
  },
})
```

### Level Progression

By default Triforce uses a **simple, easy-to-reach** leveling system.
The default leveling system is:

- **Levels 1-10**: 300 XP per level
- **Levels 11-20**: 500 XP per level
- **Levels 21+**: 1,000 XP per level

Example progression:

- **Level 5**: 1,500 XP (`5 × 300`)
- **Level 10**: 3,000 XP (`10 × 300`)
- **Level 15**: 5,500 XP (`3,000 + 5 × 500`)
- **Level 20**: 8,000 XP (`3,000 + 10 × 500`)
- **Level 30**: 18,000 XP (`8,000 + 10 × 1,000`)

You can customize this by overriding `level_progression` in your setup.
For example, to make it even easier:

```lua
require('triforce').setup({
  level_progression = {
    tier_1 = { min_level = 1, max_level = 15, xp_per_level = 200 },
    tier_2 = { min_level = 16, max_level = 30, xp_per_level = 400 },
    tier_3 = { min_level = 31, max_level = math.huge, xp_per_level = 800 },
  },
})
```

### XP Rewards

By default, Triforce awards XP for different coding activities:

- **Character typed**: 1 XP
- **New line**: 1 XP
- **File save**: 50 XP

You can customize these values to match your preferences.
For example, if you want to emphasize quality over quantity and reward saves more:

```lua
require('triforce').setup({
  xp_rewards = {
    char = 0.5,  -- Less XP for characters
    line = 2,    -- More XP for new lines
    save = 100,  -- Reward file saves heavily
  },
})
```

Or if you prefer to focus on typing volume:

```lua
require('triforce').setup({
  xp_rewards = {
    char = 2,    -- More XP per character
    line = 5,    -- Moderate XP for lines
    save = 25,   -- Less emphasis on saves
  },
})
```

---

## Usage

Triforce creates the `:Triforce` user command for your comfort. Here are the available arguments:

| Command                                                    | Description                                                                                                              |
|------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------|
| `:Triforce config`                                         | Open floating window showing your setup config                                                                           |
| `:Triforce debug languages`                                | Debug language tracking                                                                                                  |
| `:Triforce profile`                                        | Toggles the Profile UI.                                                                                                  |
| `:Triforce profile stats\|achievements\|languages\|levels` | Toggles/cycles the Profile UI. If the UI is open and the passed tab is not the same as the current, it will cycle to it. |
| `:Triforce reset`                                          | Reset all stats (useful for testing)                                                                                     |
| `:Triforce stats`                                          | Display current stats in a notification                                                                                  |
| `:Triforce stats export`                                   | Export stats to a new Neovim buffer                                                                                      |
| `:Triforce stats export <json\|markdown> </path/to/file>`  | Export stats to JSON or Markdown                                                                                         |
| `:Triforce stats save`                                     | Force save stats immediately                                                                                             |

---

## Profile UI

Keybindings:

- `<Tab>`: Cycle forward
- `<S-Tab>`: Cycle backward
- `H` / `L` or `←` / `→`: Navigate achievement/levels pages
- `q` / `Esc`: Close profile

The profile includes the following tabs:

### Stats Tab

![Stats Tab](./assets/triforce_stats.png)

- Level progress bar
- Session/time milestone progress
- Activity heatmap (7 months)
- Quick stats overview
- Directly accessible through `:Triforce profile stats`

### Achievements Tab

![Achievements Tab](./assets/triforce_achievements.png)

- View all unlocked achievements and locked achievements with unlock requirements
- Paginate through achievements (`H` / `L` or arrow keys)
- Directly accessible through `:Triforce profile achievements`

### Languages Tab

![Languages Tab](./assets/triforce_languages.png)

- Bar graph showing your most-used languages
- See character count breakdown by language
- Directly accessible through `:Triforce profile languages`

### Levels Tab

![Levels Tab](./assets/triforce_levels.png)

- View unlocked levels first, then locked ones
- Paginate through achievements (`H` / `L` or arrow keys)
- Directly accessible through `:Triforce profile levels`

---

## Achievements

Triforce includes **18 built-in achievements** across 5 categories:

### Typing Milestones

- 🌱 **First Steps**: Type 100 characters
- ⚔️ **Getting Started**: Type 1,000 characters
- 🛡️ **Dedicated Coder**: Type 10,000 characters
- 📜 **Master Scribe**: Type 100,000 characters

### Level Achievements

- ⭐ **Rising Star**: Reach level 5
- 💎 **Expert Coder**: Reach level 10
- 👑 **Champion**: Reach level 25
- 🔱 **Legend**: Reach level 50

### Session Achievements

- 🔄 **Regular Visitor**: Complete 10 sessions
- 📅 **Creature of Habit**: Complete 50 sessions
- 🏆 **Dedicated Hero**: Complete 100 sessions

### Time Achievements

- ⏰ **First Hour**: Code for 1 hour total
- ⌛ **Committed**: Code for 10 hours total
- 🕐 **Veteran**: Code for 100 hours total

### Polyglot Achievements

- 🌍 **Polyglot Beginner**: Code in 3 languages
- 🌎 **Polyglot**: Code in 5 languages
- 🌏 **Master Polyglot**: Code in 10 languages
- 🗺️ **Language Virtuoso**: Code in 15 languages

### Custom Achievements

Triforce now allows you to create new achievements with the `achievements` setup option.
**By default it's just an empty table.**

The `Achievement` type spec is shown below:

```lua
---@class Stats
---@field xp number
---@field level integer
---@field chars_typed integer
---@field lines_typed integer
---@field sessions integer
---@field time_coding integer
---@field achievements table<string, boolean>
---@field chars_by_language table<string, integer>
---@field daily_activity table<string, integer>
---@field current_streak integer
---@field longest_streak integer

-- DO NOT COPY DIRECTLY
{
  id = 'template_achievement', ---@type string
  name = '...', ---@type string
  ---@type fun(stats?: Stats): boolean
  check = function(stats)
    return stats.foo > stats.bar -- NOTE: This is just an example
  end,
  icon = '...' or nil, ---@type string|nil
  desc = '...' or nil, ---@type string|nil
}
```

Example:

```lua
require('triforce').setup({
  achievements = {
    {
      id = 'first_200',
      name = 'On Track',
      desc = 'Type 200 Characters',
      check = function(stats)
        return stats.chars_typed >= 200
      end,
    },
    {
      id = 'first_300',
      name = 'Newbie',
      desc = 'Type 300 Characters',
      check = function(stats)
        return stats.chars_typed >= 300
      end,
    },
    {
      id = 'level_100',
      name = 'God-like',
      desc = 'Reach level 100',
      icon = '󰈸',
      check = function(stats)
        return stats.level >= 100
      end,
    },
    -- ...
  },
})
```

---

## Customization

### Adding Custom Languages

Triforce supports 50+ programming languages out of the box, but you can add more:

```lua
require('triforce').setup({
  custom_languages = {
    gleam = {
      icon = '✨',
      name = 'Gleam'
    },
    zig = {
      icon = '⚡',
      name = 'Zig'
    },
  },
})
```

### Disabling Notifications

Turn off all notifications or specific types:

```lua
require('triforce').setup({
  notifications = {
    enabled = true,       -- Keep enabled
    level_up = false,     -- Disable level up notifications
    achievements = true,  -- Keep achievement notifications
  },
})
```

### Disabling Auto-Keymap

If you prefer to set your own keymap:

```lua
require('triforce').setup({
  keymap = {
    show_profile = nil, -- Don't create default keymap
  },
})

-- Set your own keymap
vim.keymap.set('n', '<C-s>', require('triforce').show_profile, { desc = 'Show Triforce Stats' })
```

### Customizing Heatmap Colors

If your colorscheme uses unconventional highlight groups, point the heatmap to
colors that fit your palette. You can mix hex colors and links to existing
highlight groups:

```lua
require('triforce').setup({
  heat_highlights = {
    TriforceHeat1 = 'Error',
    TriforceHeat2 = 'DiagnosticVirtualTextWarn',
    TriforceHeat3 = 'CursorLine',
    TriforceHeat4 = '#424242',
  },
})
```

Each key corresponds to a heat level used in the profile activity graph. If you
omit a key, the default color for that level is used.

---

## Lualine Integration

![Lualine Integration](./assets/triforce_lualine.png)

Triforce provides **modular statusline components** for
[lualine.nvim](https://github.com/nvim-lualine/lualine.nvim), letting you display your coding stats
right in your statusline.

Currently, Triforce provides the following `lualine` components (**needs a patched font**):

| Component         | Default Display | Description                  |
|-------------------|-----------------|------------------------------|
| `level`           | `Lv.27 ████░░`  | Level + XP progress bar      |
| `achievements`    | `🏆 12/18`      | Unlocked/total achievements  |
| `streak`          | `🔥 5`          | Current coding streak (days) |
| `session_time`    | `⏰ 2h 34m`     | Current session duration     |

### Basic Setup

Add Triforce components to your lualine configuration:

```lua
require('lualine').setup({
  sections = {
    lualine_x = {
      'triforce',
    },
  }
})
```

### Component Configuration

Each component can be customized independently.

#### Level Component

Options:

- `enabled` (boolean): Activates this component (default: `true`)
- `prefix` (string): Text prefix before level number (default: `'Lv.'`)
- `show` (table): Toggles for showing different components:
  - `level` (boolean): Show level number (default: `true`)
  - `bar` (boolean): Show progress bar (default: `true`)
  - `percent` (boolean): Show percentage (default: `false`)
  - `xp` (boolean): Show XP numbers like `450/500` (default: `false`)
- `bar` (table): Bar properties:
  - `length` (number): Progress bar length (default: `6`)
  - `chars` (table): `{ filled = '█', empty = '░' }` (default)

```lua
require('lualine').setup({
  sections = {
    lualine_x = {
      {
        'triforce',
        level = {
          enabled = true,
          prefix = 'Lv.',
          show = { level = true, bar = true, percent = false, xp = false },
          bar = { length = 6, chars = { filled = '█', empty = '░' } },
        },
      },
    },
  }
})
```

#### Achievements Component

Options:

- `enabled` (boolean): Activates this component (default: `false`)
- `icon` (string): Icon to display (default: `''` - trophy)
- `show_count` (boolean): Show unlocked/total count (default: `true`)

```lua
require('lualine').setup({
  sections = {
    lualine_x = {
      {
        'triforce',
        achievements = { enabled = false, icon = '', show_count = true },
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

#### Session Time Component

Options:

- `enabled` (boolean): Activates this component (default: `false`)
- `icon` (string): Icon to display (default: `''` - clock)
- `show_duration` (boolean): Show time duration (default: `true`)
- `format` (string): `'short'` (2h 34m) or `'long'` (2:34:12) (default: `'short'`)

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

### Global Component Configuration

Set defaults for all components:

```lua
require('lualine').setup({
  sections = {
    lualine_x = {
      {
        'triforce',
        level = {
          enabled = true,
          prefix = 'Lv.',
          show = {
            level = true,
            bar = true,
            percent = false,
            xp = false,
          },
          bar = {
            length = 6,
            chars = { filled = '█', empty = '░' },
          },
        },
        achievements = {
          enabled = false,
          icon = '',
          show_count = true,
        },
        streak = {
          enabled = false,
          icon = '',
          show_days = true,
        },
        session_time = {
          enabled = false,
          icon = '',
          show_duration = true,
          format = 'short',
        },
      },
    },
  }
})
```

---

## Data Storage

By default, stats are saved to `~/.local/share/nvim/triforce_stats.json`.
The file is automatically backed up before each save
to `~/.local/share/nvim/triforce_stats.json.bak`.

### Exporting

You can export your stats with the `:Triforce stats export` command.

Currently only these formats are supported:

| Format                           | Command                                         | Description                                                    |
|----------------------------------|-------------------------------------------------|----------------------------------------------------------------|
| `N/A` (export to another window) | `:Triforce stats export`                        | Raw export of your stats in another Neovim buffer.             |
| `JSON`                           | `:Triforce stats export json <PATH> [INDENT]`   | Export your stats to a given JSON file (with optional indent). |
| `Markdown`                       | `:Triforce stats export markdown <PATH>`        | Export your to a given Markdown file, with custom formatting.  |

### Data Format

```json
{
  "xp": 15420,
  "level": 12,
  "chars_typed": 45230,
  "lines_typed": 1240,
  "sessions": 42,
  "time_coding": 14580,
  "achievements": {
    "first_100": true,
    "level_10": true
  },
  "chars_by_language": {
    "lua": 12000,
    "python": 8500
  },
  "daily_activity": {
    "2025-11-07": 145,
    "2025-11-08": 203
  },
  "current_streak": 5,
  "longest_streak": 12
}
```

---

## Roadmap

- [ ] **VCS Support**: Allow individual tracking per Git branch/tag.
- [ ] **Sounds for Achievements and Level up**: Add SFX feedback for leveling up
  or completing achievements for dopamine!
- [ ] **Cloud Sync**: Sync stats across multiple devices (Firebase, GitHub Gist, or custom server)
- [ ] **Leaderboards**: Compete with friends or the community
- [X] **Exclude by Filetype**: Add filetypes you don't want to track
- [X] **Custom Achievements**: Define your own achievement criteria
- [X] **Export Stats**: Export to JSON or Markdown reports
- [ ] **Weekly/Monthly Reports**: Automated summaries via notifications
- [ ] **Themes**: Customizable color schemes for the profile UI
- [ ] **Plugin API**: Expose hooks for other plugins to integrate

**Have a feature idea?** Open an issue on GitHub!

---

## Acknowledgments

- [`nvzone/volt`](https://github.com/nvzone/volt): Beautiful UI framework.
- [`nvzone/typr`](https://github.com/nvzone/typr): Beautiful grid design component inspiration.
- [`GrzegorzSzczepanek/gamify.nvim`](https://github.com/GrzegorzSzczepanek/gamify.nvim): Another cool gamification plugin.
  Inspired the inclusion of achievements.

---

## License

MIT License - see [LICENSE](https://github.com/gisketch/triforce.nvim/blob/main/LICENSE) for details.

---

## Star History

**Made with ❤️ for the [Neovim](https://neovim.io/) community**

⭐ Star this repo if you find it useful!

<a href="https://www.star-history.com/#gisketch/triforce.nvim&type=date&legend=top-left">
  <picture>
    <source
    media="(prefers-color-scheme: dark)"
    srcset="https://api.star-history.com/svg?repos=gisketch/triforce.nvim&type=date&theme=dark&legend=top-left"
    />
    <source
    media="(prefers-color-scheme: light)"
    srcset="https://api.star-history.com/svg?repos=gisketch/triforce.nvim&type=date&legend=top-left"
    />
    <img
    alt="Star History Chart"
    src="https://api.star-history.com/svg?repos=gisketch/triforce.nvim&type=date&legend=top-left"
    />
  </picture>
</a>

<!-- vim: set ts=2 sts=2 sw=2 et ai si sta: -->
