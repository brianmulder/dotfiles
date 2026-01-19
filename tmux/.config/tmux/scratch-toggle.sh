#!/bin/sh
set -eu

# Toggle into a persistent "scratch" window inside the current tmux session.
# If the window already exists, select it; otherwise create it.

if ! tmux select-window -t scratch 2>/dev/null; then
  tmux new-window -n scratch
fi

# Keep the name stable (avoid auto-rename to running command).
tmux set-option -w automatic-rename off
tmux set-option -w allow-rename off
tmux set-option -w @scratch 1
tmux rename-window scratch
