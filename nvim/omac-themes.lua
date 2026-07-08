-- omac — every bundled theme's colorscheme plugin, declared lazy so they are
-- all *installed* but none load until :colorscheme names them (lazy.nvim
-- auto-loads a lazy colorscheme plugin on demand). This is what lets a running
-- Neovim hot-switch themes, mirroring Omarchy's nvim setup which ships all
-- theme plugins up front.
--
-- The Signal autocmd is the live half: `omac theme set` sends SIGUSR1 to every
-- running nvim; we re-read the omac-theme.lua symlink (already repointed to the
-- new theme) and apply its LazyVim colorscheme in place.

local group = vim.api.nvim_create_augroup("OmacThemeReload", { clear = true })
vim.api.nvim_create_autocmd("Signal", {
  group = group,
  pattern = "SIGUSR1",
  callback = function()
    local ok, spec = pcall(dofile, vim.fn.stdpath("config") .. "/lua/plugins/omac-theme.lua")
    if not ok or type(spec) ~= "table" then
      return
    end
    for _, plugin in ipairs(spec) do
      if
        type(plugin) == "table"
        and plugin[1] == "LazyVim/LazyVim"
        and type(plugin.opts) == "table"
        and plugin.opts.colorscheme
      then
        vim.schedule(function()
          pcall(vim.cmd.colorscheme, plugin.opts.colorscheme)
        end)
        break
      end
    end
  end,
})

return {
  { "catppuccin/nvim", name = "catppuccin", lazy = true },
  { "bjarneo/ethereal.nvim", lazy = true },
  { "neanias/everforest-nvim", lazy = true },
  { "ellisonleao/gruvbox.nvim", lazy = true },
  { "rebelot/kanagawa.nvim", lazy = true },
  { "EdenEast/nightfox.nvim", lazy = true },
  -- ristretto is a monokai-pro filter; without it the hot-switch would land on
  -- the default filter instead of the theme's flavor.
  { "gthelding/monokai-pro.nvim", lazy = true, opts = { filter = "ristretto" } },
  { "rose-pine/neovim", name = "rose-pine", lazy = true },
  { "folke/tokyonight.nvim", lazy = true },
}
