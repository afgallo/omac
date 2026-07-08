-- omac — LazyVim "extras" enabled out of the box.
-- Symlinked to ~/.config/nvim/lua/omac/extras.lua by `omac theme` wiring and
-- imported from lua/config/lazy.lua *between* `lazyvim.plugins` and your own
-- `plugins`. LazyVim requires that order (specs merge in import order), which
-- is why this file can't live in lua/plugins/ — extras imported after your
-- plugins would override your config instead of the other way around.
--
-- omac owns this file: it is a symlink back into the omac install, so edits
-- here are overwritten on upgrade. To customise, override individual plugins
-- in your own lua/plugins/ files, or toggle further extras with :LazyExtras.
--
-- Each lang extra both *installs* (mason) and *wires* (LSP + treesitter +
-- formatter + linter) a language. A bare LazyVim starter leaves that to you;
-- this closes the gap. Scope mirrors the runtimes omac installs via mise
-- (software/runtimes.manifest) plus the config/markup/doc formats every
-- project touches. Bash and Lua need nothing here — LazyVim core ships their
-- grammar and formatting; bash's LSP is added in omac-dx.lua.
return {
  -- Runtimes omac installs (software/runtimes.manifest).
  { import = "lazyvim.plugins.extras.lang.go" },
  { import = "lazyvim.plugins.extras.lang.ruby" },
  { import = "lazyvim.plugins.extras.lang.python" },
  { import = "lazyvim.plugins.extras.lang.typescript" },

  -- Universal config / markup / documentation formats.
  { import = "lazyvim.plugins.extras.lang.json" },
  { import = "lazyvim.plugins.extras.lang.yaml" },
  { import = "lazyvim.plugins.extras.lang.docker" },
  { import = "lazyvim.plugins.extras.lang.markdown" },

  -- Prettier across web/markup filetypes (js, ts, json, yaml, css, html, md).
  -- Attaches only where prettier makes sense; format-on-save then works OOTB.
  { import = "lazyvim.plugins.extras.formatting.prettier" },

  -- ESLint for JS/TS. Safe by design: only attaches when a project ships an
  -- eslint config, so non-JS projects are unaffected.
  { import = "lazyvim.plugins.extras.linting.eslint" },
}
