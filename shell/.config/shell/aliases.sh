#!/usr/bin/env sh

# Shell aliases (shared across bash/zsh).

# Navigation
alias cdr=cd_repo

# Utilities
alias clearb="clear && printf '\33c\e[3J'"
alias utc='date -u +"%Y-%m-%dT%H:%M:%SZ"'

# Quick local servers
alias rserve='ruby -run -e httpd . -p 9090'
alias pserve='python3 -m http.server 9090'
