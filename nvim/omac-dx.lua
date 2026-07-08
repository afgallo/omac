-- omac — cross-cutting editor DX for the scaffolded LazyVim config.
-- Symlinked to ~/.config/nvim/lua/plugins/omac-dx.lua by `omac theme` wiring.
--
-- omac owns this file (symlink back into the omac install; edits are overwritten
-- on upgrade). Companion to omac-lang.lua: that file adds per-language stacks,
-- this one adds the tooling that spans languages so it actually *runs* rather
-- than just being installed.
return {
  -- Prettier across web/markup filetypes (js, ts, json, yaml, css, html, md).
  -- Attaches only where prettier makes sense; format-on-save then works OOTB.
  { import = "lazyvim.plugins.extras.formatting.prettier" },

  -- ESLint for JS/TS. Safe by design: only attaches when a project ships an
  -- eslint config, so non-JS projects are unaffected.
  { import = "lazyvim.plugins.extras.linting.eslint" },

  -- vim-tmux-navigator: the nvim half of seamless Ctrl-hjkl movement between
  -- nvim splits and tmux panes. The tmux half lives in omac's shell/tmux.conf
  -- (installed via TPM). Loaded eagerly so the <C-h/j/k/l> maps exist up front.
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
    keys = {
      { "<C-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Navigate left (tmux)" },
      { "<C-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Navigate down (tmux)" },
      { "<C-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Navigate up (tmux)" },
      { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Navigate right (tmux)" },
    },
  },

  -- Bash: LazyVim core already ships the `bash` grammar and `sh -> shfmt`
  -- formatting, but no language server. Add bash-language-server (auto-installed
  -- by mason-lspconfig from the `servers` entry) and make sure shfmt is present.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        bashls = {},
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "shfmt" })
    end,
  },
}
