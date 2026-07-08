-- omac — out-of-the-box language support for the scaffolded LazyVim config.
-- Symlinked to ~/.config/nvim/lua/plugins/omac-lang.lua by `omac theme` wiring.
--
-- omac owns this file: it is a symlink back into the omac install, so edits here
-- are overwritten on upgrade. To customise, add your own file under lua/plugins/
-- (LazyVim merges specs) rather than editing this one.
--
-- Each import pulls a LazyVim "extra" that both *installs* (mason) and *wires*
-- (LSP + treesitter + formatter + linter) a language. A bare LazyVim starter
-- leaves that to you; this closes the gap. Scope mirrors the runtimes omac
-- installs via mise (software/runtimes.manifest) plus the config/markup/doc
-- formats every project touches. Bash and Lua need nothing here — LazyVim core
-- ships their grammar and formatting; bash's LSP is added in omac-dx.lua.
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
}
