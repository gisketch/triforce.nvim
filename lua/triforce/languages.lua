---@module 'triforce.types'

local Util = require('triforce.util')

---Language configuration and icons.
--- ---
---@class Triforce.Languages
local M = {}

---List of ignored languages (called from `triforce.setup()`).
--- ---
local ignored_langs = {} ---@type string[]

---Mappings for popular programming languages, in `{ name, icon }` tuples.
--- ---
local langs = { ---@type table<string, TriforceLanguage>
  PKGBUILD = { name = 'PKGBUILD', icon = '' }, -- nf-dev-terminal,
  arduino = { name = 'Arduino', icon = '' }, -- nf-dev-arduino
  asm = { name = 'Assembly', icon = '' }, -- nf-seti-asm
  bash = { name = 'Bash', icon = '' }, -- nf-dev-terminal
  c = { name = 'C', icon = '' }, -- nf-seti-c
  clojure = { name = 'Clojure', icon = '' }, -- nf-dev-clojure
  cmake = { name = 'CMake', icon = '' }, -- nf-dev-cmake
  cobol = { name = 'cobol', icon = '' }, -- nf-code-array
  conf = { name = 'Conf', icon = '' }, -- nf-seti-config
  config = { name = 'Config', icon = '' }, -- nf-seti-config
  cpp = { name = 'C++', icon = '' }, -- nf-seti-cpp
  crystal = { name = 'Crystal', icon = '' }, -- nf-seti-crystal
  cs = { name = 'C#', icon = '󰌛' }, -- nf-md-language_csharp
  csh = { name = 'C Shell', icon = '' }, -- nf-dev-terminal
  css = { name = 'CSS', icon = '' }, -- nf-dev-css3
  csv = { name = 'CSV', icon = '' }, -- nf-seti-csv
  cuda = { name = 'Cuda', icon = '' }, -- nf-seti-cu
  dart = { name = 'Dart', icon = '' }, -- nf-dev-dart
  dockerfile = { name = 'Dockerfile', icon = '󰡨' }, -- nf-md-docker
  dosini = { name = 'INI', icon = '' }, -- nf-seti-config
  elixir = { name = 'Elixir', icon = '' }, -- nf-seti-elixir
  erlang = { name = 'Erlang', icon = '' }, -- nf-dev-erlang
  fish = { name = 'Fish', icon = '' }, -- nf-dev-terminal
  fortran = { name = 'Fortran', icon = '' }, -- nf-dev-fortran
  fsharp = { name = 'F#', icon = '' }, -- nf-dev-fsharp
  glsl = { name = 'GLSL', icon = '󰫴' }, -- nf-md-alpha_g
  go = { name = 'Go', icon = '' }, -- nf-seti-go
  haskell = { name = 'Haskell', icon = '' }, -- nf-seti-haskell
  html = { name = 'HTML', icon = '' }, -- nf-dev-html5
  hyprlang = { name = 'Hyprlang', icon = '' }, -- nf-linux-hyprland
  java = { name = 'Java', icon = '' }, -- nf-dev-java
  javascript = { name = 'JavaScript', icon = '' }, -- nf-dev-javascript
  javascriptreact = { name = 'JavaScript', icon = '' }, -- nf-dev-react
  json = { name = 'JSON', icon = '' }, -- nf-seti-json
  julia = { name = 'Julia', icon = '' }, -- nf-seti-julia
  kotlin = { name = 'Kotlin', icon = '' }, -- nf-seti-kotlin
  less = { name = 'Less', icon = '' }, -- nf-dev-less
  lisp = { name = 'Common Lisp', icon = '' }, -- nf-custom-common_lisp
  lua = { name = 'Lua', icon = '' }, -- nf-seti-lua
  makefile = { name = 'Makefile', icon = '' }, -- nf-seti-makefile
  markdown = { name = 'Markdown', icon = '' }, -- nf-dev-markdown
  matplotlib = { name = 'matplotlib', icon = '' }, --nf-dev-matplotlib
  nim = { name = 'Nim', icon = '' }, -- nf-seti-nim
  ocaml = { name = 'OCaml', icon = '' }, -- nf-seti-ocaml
  org = { name = 'Org Mode', icon = '' }, -- nf-custom-orgmode
  perl = { name = 'Perl', icon = '' }, -- nf-dev-perl
  php = { name = 'PHP', icon = '' }, -- nf-dev-php
  powershell = { name = 'Power Shell', icon = '' }, -- nf-dev-terminal
  prolog = { name = 'prolog', icon = '' }, -- nf-dev-prolog
  python = { name = 'Python', icon = '' }, -- nf-dev-python
  query = { name = 'Tree-sitter Query', icon = '󰘧' }, -- nf-md-lambda
  r = { name = 'R', icon = '' }, -- nf-dev-r
  ruby = { name = 'Ruby', icon = '' }, -- nf-dev-ruby
  rust = { name = 'Rust', icon = '' }, -- nf-dev-rust
  sass = { name = 'Sass', icon = '' }, -- nf-dev-sass
  scala = { name = 'Scala', icon = '' }, -- nf-dev-scala
  scss = { name = 'SCSS', icon = '' }, -- nf-dev-sass
  sh = { name = 'Shell', icon = '' }, -- nf-dev-terminal
  sql = { name = 'SQL', icon = '' }, -- nf-dev-database
  svelte = { name = 'Svelte', icon = '' }, -- nf-seti-svelte
  swift = { name = 'Swift', icon = '' }, -- nf-dev-swift
  tex = { name = 'LaTeX', icon = '' }, -- nf-seti-tex
  toml = { name = 'TOML', icon = '' }, -- nf-seti-toml
  typescript = { name = 'TypeScript', icon = '' }, -- nf-seti-typescript
  typescriptreact = { name = 'TypeScript', icon = '' }, -- nf-dev-react
  vim = { name = 'Vimscript', icon = '' }, -- nf-seti-vim
  vue = { name = 'Vue', icon = '' }, -- nf-seti-vue
  xhtml = { name = 'XHTML', icon = '' }, -- nf-dev-html5
  xml = { name = 'XML', icon = '󰗀' }, -- nf-md-xml
  yaml = { name = 'YAML', icon = '' }, -- nf-seti-yaml
  zig = { name = 'Zig', icon = '' }, -- nf-seti-zig
  zsh = { name = 'Zsh', icon = '' }, -- nf-dev-terminal
}

---@return table<string, TriforceLanguage> langs
---@nodiscard
function M.get_langs()
  return langs
end

---@param L table<string, TriforceLanguage>
function M.set_langs(L)
  langs = vim.deepcopy(L)
end

---@return string[] ignored_langs
---@nodiscard
function M.get_ignored_langs()
  return ignored_langs
end

---@param ft string
function M.set_mini_icon(ft)
  Util.validate({ ft = { ft, { 'string' } } })

  ---@module 'mini.icons'
  if _G.MiniIcons and langs[ft] then
    local default_icon = langs[ft].icon or ''
    local no_icon = _G.MiniIcons.get('filetype', '')
    local icon = _G.MiniIcons.get('filetype', ft)
    if icon == no_icon and default_icon ~= '' then
      icon = default_icon
    elseif icon == no_icon and default_icon == '' then
      icon = no_icon
    end

    langs[ft].icon = icon
  end
end

---Get icon for a filetype.
---
---Returns `nil` if not a valid one.
---@param ft string
---@return string|nil|? icon
function M.get_icon(ft)
  Util.validate({ ft = { ft, { 'string' } } })
  if vim.list_contains(ignored_langs, ft) then
    return
  end
  if not langs[ft] then
    return ''
  end

  if require('triforce.config').get().icon_engine == 'mini' then
    M.set_mini_icon(ft)
  end

  return langs[ft].icon or ''
end

---@param ft string
---@return boolean excluded
function M.is_excluded(ft)
  Util.validate({ ft = { ft, { 'string' } } })

  return vim.list_contains(ignored_langs, ft)
end

---@param ignored string[]
function M.exclude_langs(ignored)
  Util.validate({ ignored = { ignored, { 'table' } } })

  ignored_langs = vim.tbl_deep_extend('keep', ignored, ignored_langs)
end

---Check if language should be tracked
---@param ft string
---@return boolean tracked
function M.should_track(ft)
  Util.validate({ ft = { ft, { 'string' } } })

  if ft == '' then
    return false
  end

  -- Track only if we have an icon for it or if user adds custom mapping
  return not M.is_excluded(ft) and langs[ft] and langs[ft].icon ~= nil
end

---Get display name for language.
---
---Returns `nil` if `ft` is not valid.
---@param ft string
---@return string|nil|? name
function M.get_display_name(ft)
  Util.validate({ ft = { ft, { 'string' } } })

  if M.is_excluded(ft) then
    return
  end
  return not langs[ft] and '' or (langs[ft].name or ft)
end

---Get full display with icon
---
---Returns `nil` if `ft` is not valid.
--- ---
---@param ft string
---@return string|nil|? full_display
function M.get_full_display(ft)
  Util.validate({ ft = { ft, { 'string' } } })

  if not M.is_excluded(ft) then
    local icon = M.get_icon(ft)
    local name = M.get_display_name(ft)

    if name then
      return (icon and icon ~= '') and ('%s %s'):format(icon, name) or name
    end
  end
end

---Register custom languages.
--- ---
---@param custom_langs table<string, TriforceLanguage>
function M.register_custom_languages(custom_langs)
  Util.validate({ custom_langs = { custom_langs, { 'table' } } })
  if custom_langs and not vim.tbl_isempty(custom_langs) then
    for ft, config in pairs(custom_langs) do
      if not (M.is_excluded(ft) or langs[ft]) then
        langs[ft] = { icon = config.icon or '', name = config.name or '' }
      end
    end
  end
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
