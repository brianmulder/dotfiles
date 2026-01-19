# shellcheck shell=bash
# Loaded by ~/.bashrc if present.

if [ -f "$HOME/.config/shell/env.sh" ]; then
  # shellcheck disable=SC1091
  . "$HOME/.config/shell/env.sh"
fi

if [ -f "$HOME/.config/shell/functions.sh" ]; then
  # shellcheck disable=SC1091
  . "$HOME/.config/shell/functions.sh"
fi

if [ -f "$HOME/.config/shell/aliases.sh" ]; then
  # shellcheck disable=SC1091
  . "$HOME/.config/shell/aliases.sh"
fi
