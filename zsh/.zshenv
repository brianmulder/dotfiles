# Keep zsh XDG-ish and fast.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/zcompdump"
. "$HOME/.cargo/env"
