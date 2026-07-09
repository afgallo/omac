# The shell engine: wire omac's interactive shell config into the user's
# ~/.zshrc and ~/.bashrc (idempotent managed blocks) and seed the Starship
# prompt config. Sourced by cmd/shell/* so all logic lives in one place.
#
# Pure config layer: `software` installs the tools (starship, zoxide, fzf, eza,
# bat, fd, ripgrep, mise); `theme` owns the Starship palette. The omac.zsh /
# omac.bash fragments guard every integration, so wiring is safe even before the
# tools exist — the shell just lights up whatever is installed.

source "$OMAC_HOME/lib/theme.zsh"   # render_starship / current (function defs only)

# Deploy root for starship.toml. One place so tests redirect via XDG_CONFIG_HOME.
omac::shell::config_dir() {
  print -r -- "${XDG_CONFIG_HOME:-$HOME/.config}"
}

# Absolute path to the omac fragment for a shell. Pointing the rc block straight
# at the repo means `omac update` (git pull) refreshes the shell config with no
# re-wire — same trick the theme engine uses for Ghostty's config-file.
omac::shell::fragment() {   # <zsh|bash>
  print -r -- "$OMAC_SHELL/omac.$1"
}

# Add an idempotent managed block to one rc file that sources the omac fragment.
omac::shell::wire_rc() {    # <rcfile> <zsh|bash>
  local rc="$1" shell="$2" frag; frag="$(omac::shell::fragment "$shell")"
  if [[ ! -f "$frag" ]]; then
    omac::warn "missing fragment: $frag — skipping ${rc:t}"
    return 1
  fi
  omac::ensure_block "$rc" "source \"$frag\""
  omac::ok "wired ${rc:t} -> ${frag:t}"
}

# Seed starship.toml once. Never clobber an existing file: the theme engine
# manages only the [palettes.omac] block inside it, and the rest is the user's.
omac::shell::deploy_starship() {
  local dest; dest="$(omac::shell::config_dir)/starship.toml"
  if [[ -e "$dest" ]]; then
    omac::log "exists, skipping: starship.toml"
    return 0
  fi
  mkdir -p "${dest:h}"
  cp "$OMAC_SHELL/starship.toml" "$dest"
  omac::ok "seeded starship.toml"
}

# Bootstrap TPM (tmux plugin manager) under XDG and install the plugins declared
# in shell/tmux.conf headlessly — no manual `prefix + I`. Best-effort: a missing
# git/tmux or a network hiccup warns but never fails the install. Idempotent: the
# clone no-ops once TPM exists, and install_plugins skips already-present plugins.
omac::shell::bootstrap_tpm() {   # <cfg>
  local cfg="$1" tpm="$cfg/tmux/plugins/tpm"
  command -v git >/dev/null 2>&1 || { omac::warn "git missing; skipped TPM"; return 0; }
  if [[ ! -d "$tpm" ]]; then
    omac::info "installing TPM (tmux plugin manager)"
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$tpm" >/dev/null 2>&1 \
      || { omac::warn "TPM clone failed; open tmux and press prefix + I later"; return 0; }
  fi
  if command -v tmux >/dev/null 2>&1 && [[ -x "$tpm/bin/install_plugins" ]]; then
    TMUX_PLUGIN_MANAGER_PATH="$cfg/tmux/plugins/" "$tpm/bin/install_plugins" >/dev/null 2>&1 \
      || omac::warn "tmux plugin install incomplete — open tmux and press prefix + I"
  fi
  omac::ok "tmux plugins ready (TPM)"
}

# Wire tmux: add a managed block to ~/.config/tmux/tmux.conf that sources omac's
# base config from the repo, bootstrap TPM + plugins, then render the active
# theme's colors so tmux is themed on its first start. Non-destructive: only the
# managed block is ours; anything else the user adds to tmux.conf is preserved.
omac::shell::deploy_tmux() {
  local cfg; cfg="$(omac::shell::config_dir)"
  omac::ensure_block "$cfg/tmux/tmux.conf" "source-file $OMAC_SHELL/tmux.conf"
  omac::ok "wired tmux.conf -> shell/tmux.conf"
  omac::shell::bootstrap_tpm "$cfg"
  local cur
  if cur="$(omac::theme::current 2>/dev/null)"; then
    omac::theme::render_tmux "$cur" "$cfg/tmux/omac-theme.conf"
  fi
}

# Orchestrate first-run: wire both rc files, seed starship.toml, wire tmux, then
# paint the palette from the active theme so the prompt (and tmux) are colored on
# the very first new shell — no `omac theme set` needed.
omac::shell::install() {
  omac::shell::wire_rc "$OMAC_ZSHRC"  zsh
  omac::shell::wire_rc "$OMAC_BASHRC" bash
  omac::shell::deploy_starship
  omac::shell::deploy_tmux
  local cur
  if cur="$(omac::theme::current 2>/dev/null)"; then
    omac::theme::render_starship "$cur"
  fi
  omac::ok "shell installed — open a new terminal to load it"
}

# Non-mutating status for `omac shell status`: is each rc file wired and is
# starship.toml seeded?
omac::shell::status() {
  local rc shell wired
  printf "%-12s %s\n" "COMPONENT" "WIRED"
  for rc shell in "$OMAC_ZSHRC" zsh "$OMAC_BASHRC" bash; do
    grep -qF '>>> omac >>>' "$rc" 2>/dev/null && wired=yes || wired=no
    printf "%-12s %s\n" "${rc:t}" "$wired"
  done
  [[ -f "$(omac::shell::config_dir)/starship.toml" ]] && wired=yes || wired=no
  printf "%-12s %s\n" "starship.toml" "$wired"
  grep -qF '>>> omac >>>' "$(omac::shell::config_dir)/tmux/tmux.conf" 2>/dev/null && wired=yes || wired=no
  printf "%-12s %s\n" "tmux.conf" "$wired"
}
