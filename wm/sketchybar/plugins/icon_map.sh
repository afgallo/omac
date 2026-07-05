#!/usr/bin/env bash
# omac — Nerd Font glyph helpers. Sourced by the bar + plugins.
#
# Glyphs live in the font's Private Use Area (U+E000–U+F8FF). Those codepoints
# can't be stored as literal characters here (editors/pipes strip invisible PUA
# bytes, and macOS's bash 3.2 printf has no \u escape), so we keep the hex
# codepoint and encode it to UTF-8 at runtime with \x byte escapes — which
# bash 3.2 does support. Every glyph we use is in the 3-byte BMP range.

# Hex BMP codepoint (0x0800–0xFFFF) -> its UTF-8 bytes.
omac::glyph() {  # <hex-codepoint>
  local cp=$((16#$1))
  printf '\x'"$(printf '%02x' $(( 0xE0 |  cp >> 12        )))"
  printf '\x'"$(printf '%02x' $(( 0x80 | (cp >> 6 & 0x3F) )))"
  printf '\x'"$(printf '%02x' $(( 0x80 | (cp      & 0x3F) )))"
}

# App name -> glyph. Unknown apps fall back to a generic window glyph so the
# workspace strip never renders a blank/tofu box.
omac::icon_for() {  # <app-name>
  local cp
  case "$1" in
    "Ghostty"|"Terminal"|"iTerm2"|"Alacritty"|"kitty"|"WezTerm")  cp=f120 ;; # terminal
    "Safari"|"Safari Technology Preview")                          cp=f267 ;; # safari
    "Google Chrome"|"Chromium"|"Brave Browser")                   cp=f268 ;; # chrome
    "Firefox"|"Firefox Developer Edition")                         cp=f269 ;; # firefox
    "Arc")                                                         cp=f0ac ;; # globe
    "Visual Studio Code"|"Code"|"VSCodium"|"Cursor"|"Xcode")      cp=f121 ;; # code
    "Obsidian"|"Notes"|"Notion")                                  cp=f249 ;; # note
    "Slack")                                                       cp=f198 ;; # slack
    "Discord")                                                     cp=f392 ;; # discord
    "Signal"|"Messages")                                          cp=f075 ;; # comment
    "Spotify"|"Music")                                            cp=f1bc ;; # spotify
    "Mail"|"HEY")                                                 cp=f0e0 ;; # envelope
    "Finder")                                                     cp=f07b ;; # folder
    "Preview")                                                    cp=f1c5 ;; # image
    "System Settings"|"System Preferences")                       cp=f013 ;; # cog
    "1Password"|"1Password 7 - Password Manager")                 cp=f023 ;; # lock
    "Docker"|"Docker Desktop")                                    cp=e7b0 ;; # docker
    "zoom.us"|"Zoom")                                             cp=f03d ;; # video
    "Calendar")                                                   cp=f073 ;; # calendar
    "ChatGPT"|"Claude")                                           cp=f544 ;; # robot
    *)                                                            cp=f2d0 ;; # window
  esac
  omac::glyph "$cp"
}
