# The theme engine: switch among the 10 bundled themes. Owns colors everywhere.
# software installs the apps; wm left the JankyBorders colors.sh seam for this.
# All logic lives here; cmd/theme/* stay thin. Functions namespaced omac::theme::*.

# The font seam is a sibling module: theme::set/wire delegate the ghostty font
# include to omac::font::ensure_ghostty_seam so a theme switch preserves the
# typeface. Guarded so unit tests that source theme.zsh in isolation still load.
[[ -f "$OMAC_HOME/lib/font.zsh" ]] && source "$OMAC_HOME/lib/font.zsh"

# Deploy root. One place so tests redirect via XDG_CONFIG_HOME.
omac::theme::config_dir() {
  print -r -- "${XDG_CONFIG_HOME:-$HOME/.config}"
}

# Flat-TOML reader now lives in common.zsh (shared with the font module).
# Kept as a thin alias so the many omac::theme::toml_get call sites stay put.
omac::theme::toml_get() { omac::toml_get "$@"; }        # <file> <key>

# Print bundled theme basenames, sorted.
omac::theme::list_names() {
  setopt local_options null_glob
  local d
  for d in "$OMAC_THEMES"/*(/); do
    print -r -- "${d:t}"
  done | sort
}

omac::theme::is_theme() {        # <name>
  [[ -d "$OMAC_THEMES/$1" ]]
}

omac::theme::is_light() {        # <name>
  [[ -f "$OMAC_THEMES/$1/light.mode" ]]
}

# Active theme: resolve the current symlink, else the persisted var.
omac::theme::current() {
  if [[ -L "$OMAC_CURRENT" ]]; then
    local tgt; tgt="$(readlink "$OMAC_CURRENT")"
    print -r -- "${tgt:t}"; return 0
  fi
  if [[ -n "${OMAC_ACTIVE_THEME:-}" ]]; then
    print -r -- "$OMAC_ACTIVE_THEME"; return 0
  fi
  return 1
}

# --- Renderers (pure: read a theme, write a target file) ---------------------

# #rrggbb -> 0xAARRGGBB (the form JankyBorders' colors.sh uses). Alpha defaults
# to ff (opaque); pass a two-hex-digit alpha for translucent tones.
omac::theme::hex_to_argb() {     # <#rrggbb> [aa]
  local h="${1#\#}" a="${2:-ff}"
  print -r -- "0x$a$h"
}

# Ghostty color fragment: a built-in name if apps.toml has one, else a palette
# block. Font lives in a separate omac-font.conf (see lib/font.zsh) so the theme
# and font seams stay orthogonal — a theme switch never touches the typeface.
omac::theme::render_ghostty() {  # <name> <dest-file>
  local name="$1" dest="$2" dir="$OMAC_THEMES/$1"
  local builtin; builtin="$(omac::theme::toml_get "$dir/apps.toml" ghostty)" || builtin=""
  mkdir -p "${dest:h}"
  if [[ -n "$builtin" ]]; then
    print -r -- "theme = $builtin" > "$dest"
    return 0
  fi
  # Palette fallback — Ghostty accepts hex without '#' for fg/bg/cursor.
  local pal="$dir/colors.toml" k v i
  {
    for k in foreground background; do
      v="$(omac::theme::toml_get "$pal" "$k")" && print -r -- "$k = ${v#\#}"
    done
    v="$(omac::theme::toml_get "$pal" cursor)"               && print -r -- "cursor-color = ${v#\#}"
    v="$(omac::theme::toml_get "$pal" selection_background)" && print -r -- "selection-background = ${v#\#}"
    v="$(omac::theme::toml_get "$pal" selection_foreground)" && print -r -- "selection-foreground = ${v#\#}"
    for i in {0..15}; do
      v="$(omac::theme::toml_get "$pal" "color$i")" && print -r -- "palette = $i=$v"
    done
  } > "$dest"
}

# Build the Starship `[palettes.omac]` TOML table from a theme's colors.toml.
# Maps the base16-style palette to the semantic names shell/starship.toml uses.
# Prints the table text (no file I/O); returns 1 only if colors.toml is unreadable.
omac::theme::starship_palette() {   # <name>
  local pal="$OMAC_THEMES/$1/colors.toml"
  [[ -f "$pal" ]] || return 1
  local pair nm key v
  print -r -- "[palettes.omac]"
  for pair in accent:accent fg:foreground bg:background \
              black:color0 red:color1 green:color2 yellow:color3 \
              blue:color4 magenta:color5 cyan:color6 white:color7 \
              bright_black:color8; do
    nm="${pair%%:*}"; key="${pair##*:}"
    v="$(omac::theme::toml_get "$pal" "$key")" && print -r -- "$nm = \"$v\""
  done
  return 0   # a missing optional color (last loop iter) must not fail the block
}

# Starship: rewrite the managed [palettes.omac] block inside the user's
# starship.toml with colors derived from the theme. No-op when the shell module
# has not seeded starship.toml yet (the palette is meaningless without it), so
# theme/shell install order does not matter.
omac::theme::render_starship() {   # <name>
  local f; f="$(omac::theme::config_dir)/starship.toml"
  [[ -f "$f" ]] || return 0
  local block; block="$(omac::theme::starship_palette "$1")" || return 0
  omac::remove_block "$f"
  omac::ensure_block "$f" "$block"
  omac::info "starship palette: $1"
}

# JankyBorders colors.sh from the palette: the focused window's border is the
# accent (opaque); unfocused windows get a faint foreground tint so their bounds
# stay legible without competing with the focused one.
omac::theme::render_borders() {   # <name> <dest-file>
  local dir="$OMAC_THEMES/$1" dest="$2" fg ac
  fg="$(omac::theme::toml_get "$dir/colors.toml" foreground)"
  ac="$(omac::theme::toml_get "$dir/colors.toml" accent)"
  mkdir -p "${dest:h}"
  {
    print -r -- "#!/usr/bin/env bash"
    print -r -- "# omac — rendered by 'omac theme set'. Do not edit."
    print -r -- "export ACTIVE_COLOR=$(omac::theme::hex_to_argb "$ac")"
    print -r -- "export INACTIVE_COLOR=$(omac::theme::hex_to_argb "$fg" 40)"
  } > "$dest"
}

# tmux status colors from the palette. tmux takes `#rrggbb` verbatim (no 0xAA
# conversion, unlike JankyBorders). Replaces the hardcoded theme plugin an Omarchy
# setup would use, so the status line follows `omac theme set`. Sourced by
# shell/tmux.conf as ~/.config/tmux/omac-theme.conf.
omac::theme::render_tmux() {     # <name> <dest-file>
  local dir="$OMAC_THEMES/$1" dest="$2" bg fg ac lo
  bg="$(omac::theme::toml_get "$dir/colors.toml" background)"
  fg="$(omac::theme::toml_get "$dir/colors.toml" foreground)"
  ac="$(omac::theme::toml_get "$dir/colors.toml" accent)"
  lo="$(omac::theme::toml_get "$dir/colors.toml" color8)" || lo="$fg"  # dim/inactive
  mkdir -p "${dest:h}"
  {
    print -r -- "# omac — rendered by 'omac theme set'. Do not edit."
    print -r -- "set -g status-style \"bg=$bg,fg=$fg\""
    print -r -- "set -g window-status-current-style \"bg=$ac,fg=$bg,bold\""
    print -r -- "set -g window-status-style \"fg=$fg\""
    print -r -- "set -g pane-border-style \"fg=$lo\""
    print -r -- "set -g pane-active-border-style \"fg=$ac\""
    print -r -- "set -g mode-style \"bg=$ac,fg=$bg\""
    print -r -- "set -g message-style \"bg=$ac,fg=$bg\""
  } > "$dest"
}

# Absolute path of the theme's default background. Backgrounds follow the
# `NN-name.ext` convention (zero-padded from 01); `01-` is the default, so the
# first omarchy-free file wins. See docs/themes for the naming contract.
omac::theme::first_background() {    # <name>
  setopt local_options null_glob
  local dir="$OMAC_THEMES/$1/backgrounds" f
  local -a files
  for f in "$dir"/*(.); do
    [[ "${f:t:l}" == *omarchy* ]] && continue
    files+=("$f")
  done
  (( ${#files} )) || return 1
  files=(${(o)files})              # sort
  print -r -- "${files[1]}"
}

# --- System appliers (side effects: osascript / editor settings) -------------

# macOS light/dark. Live via System Events.
omac::theme::apply_appearance() {    # <name>
  local dark=true
  omac::theme::is_light "$1" && dark=false
  omac::info "appearance: dark=$dark"
  osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $dark" >/dev/null 2>&1 \
    || omac::warn "could not set appearance (System Events)"
}

# Desktop wallpaper: the theme's default background. Live.
# macOS 14 Sonoma / 15 Sequoia broke the System Events `set picture` API (it
# returns success but silently no-ops), so prefer the `wallpaper` CLI that
# `software` installs for exactly this. Fall back to osascript where it's absent
# (older macOS, or a minimal install without the wm/software layer).
omac::theme::apply_wallpaper() {     # <name>
  local bg; bg="$(omac::theme::first_background "$1")" || { omac::warn "no background for $1"; return 0; }
  omac::info "wallpaper: ${bg:t}"
  if command -v wallpaper >/dev/null 2>&1; then
    wallpaper set "$bg" >/dev/null 2>&1 || omac::warn "could not set wallpaper (wallpaper CLI)"
  else
    omac::warn "no 'wallpaper' CLI — wallpaper may not stick on macOS 14+ (run: omac software install)"
    osascript -e "tell application \"System Events\" to set picture of every desktop to \"$bg\"" >/dev/null 2>&1 \
      || omac::warn "could not set wallpaper"
  fi
}

# Write workbench.colorTheme into one editor settings file (create/replace/insert).
omac::theme::_vscode_write() {       # <colorTheme> <settings-file>
  omac::json_set_raw "$2" "workbench.colorTheme" "\"$1\""
}

# VS Code/Cursor settings root. NOT XDG on macOS — they read ~/Library/Application Support.
# One place so tests redirect via OMAC_APPSUPPORT.
omac::theme::appsupport_dir() {
  print -r -- "$OMAC_APPSUPPORT"
}

# Apply the VS Code colorTheme to VS Code and Cursor (whichever config dirs exist).
omac::theme::apply_vscode() {        # <colorTheme>
  local name="$1" as; as="$(omac::theme::appsupport_dir)"
  omac::theme::_vscode_write "$name" "$as/Code/User/settings.json"
  [[ -d "$as/Cursor" ]] && omac::theme::_vscode_write "$name" "$as/Cursor/User/settings.json"
  omac::info "editor theme: $name"
}

# bat: write a managed --theme block into ~/.config/bat/config when the theme
# names a bat built-in; no-op otherwise. Best-effort (needs the `bat` CLI).
omac::theme::apply_bat() {           # <name>
  local theme; theme="$(omac::theme::toml_get "$OMAC_THEMES/$1/apps.toml" bat)" || return 0
  [[ -n "$theme" ]] || return 0
  if ! command -v bat >/dev/null 2>&1; then
    omac::warn "no 'bat' — skipping bat theme"; return 0
  fi
  local f; f="$(omac::theme::config_dir)/bat/config"
  mkdir -p "${f:h}"
  omac::remove_block "$f"
  omac::ensure_block "$f" "--theme=\"$theme\""
  omac::info "bat theme: $theme"
}

# git-delta: reuse the theme's bat name as delta's syntax-theme (shared
# namespace). No-op when unnamed; best-effort (needs `git`).
omac::theme::apply_delta() {         # <name>
  local theme; theme="$(omac::theme::toml_get "$OMAC_THEMES/$1/apps.toml" bat)" || return 0
  [[ -n "$theme" ]] || return 0
  if ! command -v git >/dev/null 2>&1; then
    omac::warn "no 'git' — skipping delta theme"; return 0
  fi
  git config --global delta.syntax-theme "$theme" 2>/dev/null \
    || omac::warn "could not set delta syntax-theme"
  omac::info "delta syntax-theme: $theme"
}

# --- Orchestration -----------------------------------------------------------

# Persist the active theme. config_set upserts just this key, leaving the font
# module's OMAC_ACTIVE_FONT entry in the same managed block untouched.
omac::theme::persist() {         # <name>
  omac::config_set OMAC_ACTIVE_THEME "$1"
}

# The switch: validate, repoint current, render/apply every target, persist.
omac::theme::set() {             # <name>
  local name="$1"
  if [[ -z "$name" ]] || ! omac::theme::is_theme "$name"; then
    omac::error "unknown theme: ${name:-<none>}"
    omac::theme::list_names
    return 1
  fi
  local cfg; cfg="$(omac::theme::config_dir)"

  # 1. Repoint the current symlink (class-B ported files reachable via current).
  mkdir -p "$OMAC_CONFIG"
  ln -sfn "$OMAC_THEMES/$name" "$OMAC_CURRENT"

  # 2. Render class-A/C targets into their app locations.
  omac::theme::render_ghostty "$name" "$cfg/ghostty/omac-theme.conf"
  omac::theme::render_borders "$name" "$cfg/borders/colors.sh"
  omac::theme::render_tmux "$name" "$cfg/tmux/omac-theme.conf"
  # 2b. Font seam (self-heal): keep the ghostty config including omac-font.conf
  #     and seed a default font file if absent, so the include never dangles.
  #     Never overwrites an existing font choice — orthogonal to the theme.
  omac::font::ensure_ghostty_seam "$cfg"

  # 3. Editors (best-effort): VS Code colorTheme from the theme's vscode.json.
  #    vscode.json is JSON ("name": "..."), so read it JSON-aware, not via toml_get.
  local ct; ct="$(grep -E '"name"[[:space:]]*:' "$OMAC_THEMES/$name/vscode.json" 2>/dev/null \
                  | head -1 | sed -E 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
  [[ -n "$ct" ]] && omac::theme::apply_vscode "$ct"

  # 3b. bat + git-delta (best-effort): both driven by the apps.toml `bat` name.
  omac::theme::apply_bat "$name"
  omac::theme::apply_delta "$name"

  # 3c. Neovim (self-heal): scaffold LazyVim once if missing, keep the themed
  #     plugin symlink in place. No-op after the first successful scaffold.
  omac::theme::wire_nvim "$cfg"

  # 3d. Starship palette (best-effort): derived from colors.toml; no-op until
  #     the shell module has seeded starship.toml.
  omac::theme::render_starship "$name"

  # 4-5. Appearance + wallpaper.
  omac::theme::apply_appearance "$name"
  omac::theme::apply_wallpaper "$name"

  # 6. Reload what can reload live.
  # borders: re-run the deployed bordersrc to push the new colors to the live
  # daemon (no-op / harmless if borders isn't running).
  local brc="$cfg/borders/bordersrc"
  command -v borders >/dev/null 2>&1 && [[ -x "$brc" ]] && "$brc" >/dev/null 2>&1
  # tmux: re-source the rendered colors into any running server (no-op if none).
  command -v tmux >/dev/null 2>&1 && tmux source-file "$cfg/tmux/omac-theme.conf" >/dev/null 2>&1
  # Ghostty: SIGUSR2 makes it re-read its config live (Ghostty >= 1.2; same
  # mechanism Omarchy's theme-set uses). Must go through signal_app — pkill
  # can't see the macOS app-bundle process (see signal_app).
  omac::signal_app USR2 ghostty
  # Neovim: SIGUSR1 fires the Signal autocmd registered by omac-themes.lua,
  # which re-reads the repointed theme symlink and re-applies the colorscheme.
  omac::signal_app USR1 nvim

  # 7. Persist.
  omac::theme::persist "$name"

  omac::ok "theme set: $name"
  omac::info "running apps reload live; first nvim launch installs any new colorschemes"
}

# Re-apply the current theme (re-render + reload) without changing the selection.
omac::theme::reload() {
  local name; name="$(omac::theme::current)" || { omac::error "no active theme"; return 1; }
  omac::theme::set "$name"
}

# --- One-time wiring (install) -----------------------------------------------

# Install one extension via <cli>, retrying transient marketplace/network
# failures (the #1 cause of a spurious "failed:" during `theme install`).
# "Already installed" exits 0, so it counts as success. On the final failed
# attempt the captured output is echoed so the caller can report *why*.
omac::theme::_install_ext() {   # <cli> <id>
  local cli="$1" id="$2" attempt out
  for attempt in 1 2 3; do
    if out="$("$cli" --install-extension "$id" 2>&1)"; then
      return 0
    fi
    (( attempt < 3 )) && sleep 2
  done
  print -r -- "$out"
  return 1
}

# Pre-install the distinct VS Code/Cursor theme extensions across all themes.
omac::theme::install_extensions() {
  setopt local_options null_glob
  local -a ids; local f id err
  for f in "$OMAC_THEMES"/*/vscode.json; do
    id="$(grep -E '"extension"[[:space:]]*:' "$f" 2>/dev/null \
          | head -1 | sed -E 's/.*"extension"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
    [[ -n "$id" ]] && ids+=("$id")
  done
  ids=(${(u)ids})                 # dedupe
  if ! command -v code >/dev/null 2>&1; then
    omac::warn "no 'code' CLI — skipping VS Code extension pre-install"
    return 0
  fi
  for id in $ids; do
    omac::info "installing extension: $id"
    if ! err="$(omac::theme::_install_ext code "$id")"; then
      omac::warn "failed: $id — ${err##*$'\n'}"
    fi
    command -v cursor >/dev/null 2>&1 && omac::theme::_install_ext cursor "$id" >/dev/null 2>&1
  done
}

# Scaffold the LazyVim starter into <cfg>/nvim so the themed `neovim.lua` we
# symlink below has a real LazyVim base to load. Non-destructive: if any nvim
# config already exists we leave it untouched (bring your own LazyVim layout).
# Follows https://www.lazyvim.org/installation.
omac::theme::bootstrap_lazyvim() {   # <cfg>
  local nvim="$1/nvim"
  [[ -e "$nvim" ]] && return 0
  command -v git >/dev/null 2>&1 || { omac::warn "git missing; skipped LazyVim scaffold"; return 0; }
  omac::info "scaffolding LazyVim starter into $nvim"
  if git clone --depth 1 https://github.com/LazyVim/starter "$nvim" >/dev/null 2>&1; then
    rm -rf "$nvim/.git"
    omac::ok "LazyVim installed — launch nvim, then run :LazyHealth"
  else
    rm -rf "$nvim" 2>/dev/null   # don't leave a half-cloned config behind
    omac::warn "LazyVim scaffold failed (git clone); themed nvim won't load until installed"
  fi
}

# LazyVim requires extras to be imported after `lazyvim.plugins` but before the
# user's own `plugins` (specs merge in import order — extras imported last would
# override user config, and LazyVim warns on startup). So omac's extras module
# can't sit in lua/plugins/; it must be imported from lua/config/lazy.lua's spec.
# Insert `{ import = "omac.extras" }` once, anchored on the starter's
# `{ import = "plugins" }` line. Idempotent: the first grep makes re-runs no-ops.
# A user who restructured lazy.lua beyond recognition just gets a warn telling
# them to add the import themselves; their file is never touched blindly.
omac::theme::wire_lazy_extras() {   # <cfg>
  local lazy="$1/nvim/lua/config/lazy.lua"
  [[ -f "$lazy" ]] || return 0
  grep -qF 'omac.extras' "$lazy" && return 0
  local anchor='{ import = "plugins" }'
  if ! grep -qF "$anchor" "$lazy"; then
    omac::warn "no ${anchor} spec line in $lazy — add { import = \"omac.extras\" } before your plugins import"
    return 0
  fi
  local tmp="$lazy.omac-new"
  awk -v anchor="$anchor" '
    !done && index($0, anchor) {
      match($0, /^[ \t]*/); indent = substr($0, 1, RLENGTH)
      print indent "-- omac-managed LazyVim extras (must import before your own plugins)"
      print indent "{ import = \"omac.extras\" },"
      done = 1
    }
    { print }
  ' "$lazy" > "$tmp"
  omac::backup_path "$lazy"
  mv "$tmp" "$lazy"
  omac::ok "wired omac.extras import into nvim/lua/config/lazy.lua"
}

# Scaffold LazyVim (once) and drop omac's plugin symlinks into it:
#   omac-theme.lua  -> the current theme's colorscheme spec (repoints per `set`)
#   omac-themes.lua -> ALL themes' colorscheme plugins (lazy) + the SIGUSR1
#                      hot-reload autocmd, so running instances switch live
#   omac-dx.lua     -> cross-cutting DX (tmux navigation, bash LSP, shfmt)
#   omac/extras.lua -> LazyVim extras (language stacks, prettier, eslint),
#                      imported from config/lazy.lua via wire_lazy_extras
# dx/extras are omac-owned and theme-independent, so they point at the omac
# install rather than the per-theme `current` link. Together they make the
# scaffolded LazyVim deliver a real out-of-the-box editing experience, not a
# bare starter. Idempotent: bootstrap_lazyvim no-ops once <cfg>/nvim exists;
# ln -sfn is safe to re-run. Callable from both first-run wiring and every
# `set` so a machine themed via `set` before `install` still gets a real
# LazyVim base.
omac::theme::wire_nvim() {   # <cfg>
  local cfg="$1"
  omac::theme::bootstrap_lazyvim "$cfg"
  mkdir -p "$cfg/nvim/lua/plugins" "$cfg/nvim/lua/omac"
  ln -sfn "$OMAC_CURRENT/neovim.lua"   "$cfg/nvim/lua/plugins/omac-theme.lua"
  ln -sfn "$OMAC_NVIM/omac-themes.lua" "$cfg/nvim/lua/plugins/omac-themes.lua"
  ln -sfn "$OMAC_NVIM/omac-dx.lua"     "$cfg/nvim/lua/plugins/omac-dx.lua"
  ln -sfn "$OMAC_NVIM/omac-extras.lua" "$cfg/nvim/lua/omac/extras.lua"
  # Pre-extras layouts linked omac-lang.lua into lua/plugins/ — remove it so
  # its extras imports stop tripping LazyVim's import-order check.
  [[ -L "$cfg/nvim/lua/plugins/omac-lang.lua" ]] && rm -f "$cfg/nvim/lua/plugins/omac-lang.lua"
  omac::theme::wire_lazy_extras "$cfg"
  omac::theme::wire_nvim_explorer "$cfg"
}

# Make neo-tree the default file explorer. LazyVim resolves its explorer (like
# its picker and completion) as a mutually-exclusive "default" while sourcing
# `lazyvim.plugins`, *before* omac's extras module is imported — so a bare
# `{ import = editor.neo-tree }` in omac-extras.lua is silently dropped and the
# snacks explorer wins (this bit us: the import simply never installed). The
# supported override is the `vim.g.lazyvim_explorer` global, which LazyVim reads
# first (LazyVim.config.register_defaults) and which must be set in
# lua/config/options.lua — loaded via M.load("options") before any plugin spec
# is sourced. Drop it there in a managed block. Can't use omac::ensure_block:
# its `#` markers are a syntax error in Lua, so this hand-rolls the same
# idempotent append with `--` comment markers. The grep guard also means a user
# who has already chosen an explorer (any lazyvim_explorer line) is left alone.
omac::theme::wire_nvim_explorer() {   # <cfg>
  local opts="$1/nvim/lua/config/options.lua"
  mkdir -p "${opts:h}"
  [[ -f "$opts" ]] || : > "$opts"
  grep -qF 'lazyvim_explorer' "$opts" && return 0
  {
    print -r -- ""
    print -r -- "-- >>> omac >>>"
    print -r -- 'vim.g.lazyvim_explorer = "neo-tree" -- omac: default file explorer'
    print -r -- "-- <<< omac <<<"
  } >> "$opts"
  omac::ok "set neo-tree as nvim's default explorer (lua/config/options.lua)"
}

# Point the user's real app configs at omac (idempotent managed blocks/symlink).
# The ghostty config block lists both omac includes (theme colors + font); the
# font module owns that block so the two seams stay in sync.
omac::theme::wire() {
  local cfg; cfg="$(omac::theme::config_dir)"
  omac::font::ensure_ghostty_seam "$cfg"
  omac::theme::wire_nvim "$cfg"
  omac::ok "wired ghostty, neovim"
}

# Full first-run: extensions, wiring, then apply the default theme.
omac::theme::install() {
  omac::theme::install_extensions
  omac::theme::wire
  omac::theme::set "$OMAC_DEFAULT_THEME"
  omac::ok "theme installed (default: $OMAC_DEFAULT_THEME)"
}
