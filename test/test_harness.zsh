#!/usr/bin/env zsh
emulate -L zsh
source "${0:A:h}/helper.zsh"
check "check compares equal strings" "abc" "abc"
contains "contains finds substring" "bc" "abcd"
finish
