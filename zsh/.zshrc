# Minimal zsh config focused on speed + low cognitive load.

if [[ -n "${ZSH_PROFILE:-}" ]]; then
  zmodload zsh/zprof
fi

setopt autocd

# --- History ---------------------------------------------------------------
# Goal: long, shared history across tmux panes/windows and shells.
# Keep duplicates reasonable without nuking history depth.
setopt append_history
setopt inc_append_history
setopt share_history
setopt hist_fcntl_lock
setopt hist_ignore_dups
setopt hist_reduce_blanks
setopt extended_history

HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
HISTSIZE=50000
# shellcheck disable=SC2034
SAVEHIST=50000

# --- Completion ------------------------------------------------------------
# Case-insensitive tab completion (filesystem + commands).
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

autoload -Uz compinit
zcompdump="${ZSH_COMPDUMP:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump}"
mkdir -p "${zcompdump:h}" 2>/dev/null || true

# Always take the fast path. Refresh manually after installing new completions.
if [[ -f $zcompdump ]]; then
  compinit -C -d "$zcompdump" -i
else
  compinit -d "$zcompdump" -i
fi

recompinit() {
  rm -f "$zcompdump"* 2>/dev/null || true
  compinit -d "$zcompdump" -i
}

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

# --- Keybindings -----------------------------------------------------------
# Ensure Ctrl-R reverse history search works reliably (tmux panes, fresh shells, etc).
bindkey -M emacs '^R' history-incremental-search-backward 2>/dev/null || true
bindkey -M viins '^R' history-incremental-search-backward 2>/dev/null || true
bindkey '^R' history-incremental-search-backward 2>/dev/null || true

# Prompt: Starship if installed, otherwise a minimal fallback.
if command -v starship >/dev/null 2>&1; then
  starship_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/starship"
  starship_init="$starship_cache_dir/init.zsh"

  mkdir -p "$starship_cache_dir" 2>/dev/null || true

  # Cache the init script (refresh daily) to keep shell startup snappy.
  starship_refresh_init=0
  if [[ ! -s "$starship_init" || -n ${starship_init}(#qN.mh+24) ]]; then
    starship_refresh_init=1
  fi

  if (( starship_refresh_init == 1 )); then
    starship init zsh >| "$starship_init" 2>/dev/null || true
  fi
  unset starship_refresh_init

  if [[ -s "$starship_init" ]]; then
    # shellcheck disable=SC1090
    . "$starship_init"
  else
    # shellcheck disable=SC2034
    PROMPT='%F{green}%n@%m%f:%F{blue}%~%f$ '
  fi
else
  # shellcheck disable=SC2034
  PROMPT='%F{green}%n@%m%f:%F{blue}%~%f$ '
fi

# Local-only overrides (not tracked).
if [ -f "$HOME/.config/shell/local.zsh" ]; then
  # shellcheck disable=SC1091
  . "$HOME/.config/shell/local.zsh"
fi

if [[ -n "${ZSH_PROFILE:-}" ]]; then
  zprof
fi
