#!/usr/bin/env sh

# Minimal, cross-shell environment setup.
# Sourced by both bash and zsh.

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

if [ -z "${XDG_RUNTIME_DIR:-}" ] || [ ! -d "${XDG_RUNTIME_DIR:-}" ] || [ ! -w "${XDG_RUNTIME_DIR:-}" ]; then
  export XDG_RUNTIME_DIR="$XDG_STATE_HOME/run"
  mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true
fi

export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-nvim}"

# --- Language/tooling -------------------------------------------------------

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ ! -d "$NVM_DIR" ] && [ -d "$HOME/.nvm" ]; then
  export NVM_DIR="$HOME/.nvm"
fi

path_prepend() {
  [ -d "$1" ] || return 0
  path_remove "$1"
  if [ -n "${PATH:-}" ]; then
    PATH="$1:$PATH"
  else
    PATH="$1"
  fi
}

path_append() {
  [ -d "$1" ] || return 0
  path_remove "$1"
  if [ -n "${PATH:-}" ]; then
    PATH="$PATH:$1"
  else
    PATH="$1"
  fi
}

path_remove() {
  [ -n "${PATH:-}" ] || return 0
  path_remove_target="$1"
  path_remove_out=""
  path_remove_old_ifs="$IFS"
  IFS=":"
  # shellcheck disable=SC2086
  for path_remove_part in $PATH; do
    [ -n "$path_remove_part" ] || continue
    [ "$path_remove_part" = "$path_remove_target" ] && continue
    if [ -z "$path_remove_out" ]; then
      path_remove_out="$path_remove_part"
    else
      path_remove_out="$path_remove_out:$path_remove_part"
    fi
  done
  IFS="$path_remove_old_ifs"
  unset path_remove_target path_remove_old_ifs path_remove_part
  PATH="$path_remove_out"
  unset path_remove_out
}

# Prefer user-local bins.
path_prepend "$HOME/bin"
path_prepend "$HOME/.local/bin"

# Make `node` available for non-interactive scripts without loading nvm.
# This prevents issues when WSL PATH includes Windows npm shims that `exec node`.
nvm_node_bin=""
nvm_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/nvm"
nvm_cache_file="$nvm_cache_dir/default-node-bin"

cache_ok=0
if [ -s "$nvm_cache_file" ]; then
  cache_ok=1
  if [ -f "$NVM_DIR/alias/default" ] && [ "$NVM_DIR/alias/default" -nt "$nvm_cache_file" ]; then
    cache_ok=0
  fi
  if [ -d "$NVM_DIR/versions/node" ] && [ "$NVM_DIR/versions/node" -nt "$nvm_cache_file" ]; then
    cache_ok=0
  fi
fi

if [ "$cache_ok" -eq 1 ]; then
  nvm_node_bin="$(cat "$nvm_cache_file" 2>/dev/null || true)"
fi

if [ -n "$nvm_node_bin" ] && [ -d "$nvm_node_bin" ]; then
  path_prepend "$nvm_node_bin"
else
  nvm_node_bin=""
  if [ -d "$NVM_DIR/versions/node" ]; then
    default_node=""
    if [ -f "$NVM_DIR/alias/default" ]; then
      default_node="$(cat "$NVM_DIR/alias/default" 2>/dev/null || true)"
    fi
    if [ -n "$default_node" ] && [ -d "$NVM_DIR/versions/node/$default_node/bin" ]; then
      nvm_node_bin="$NVM_DIR/versions/node/$default_node/bin"
    else
      latest_node="$(find "$NVM_DIR/versions/node" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort -V | tail -n 1)"
      if [ -n "${latest_node:-}" ] && [ -d "$NVM_DIR/versions/node/$latest_node/bin" ]; then
        nvm_node_bin="$NVM_DIR/versions/node/$latest_node/bin"
      fi
    fi
  fi

  if [ -n "$nvm_node_bin" ]; then
    path_prepend "$nvm_node_bin"
    mkdir -p "$nvm_cache_dir" 2>/dev/null || true
    printf "%s\n" "$nvm_node_bin" >"$nvm_cache_file" 2>/dev/null || true
  fi
fi

# NVM (lazy-load to keep shells fast).
if [ -s "$NVM_DIR/nvm.sh" ]; then
  _nvm_lazy_load() {
    unset -f nvm node npm npx 2>/dev/null || true
    # shellcheck disable=SC1090,SC1091
    . "$NVM_DIR/nvm.sh"
  }
  nvm() { _nvm_lazy_load; nvm "$@"; }
  node() { _nvm_lazy_load; node "$@"; }
  npm() { _nvm_lazy_load; npm "$@"; }
  npx() { _nvm_lazy_load; npx "$@"; }
fi

export ANDROID_HOME="${ANDROID_HOME:-$HOME/android}"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"

path_append "$ANDROID_HOME/cmdline-tools/latest/bin"
path_append "$ANDROID_HOME/platform-tools"
path_append "$JAVA_HOME/bin"

# Local, machine-specific overrides (not tracked).
# Good place for secrets like OPENAI_API_KEY.
if [ -f "$XDG_CONFIG_HOME/shell/env.local.sh" ]; then
  # shellcheck disable=SC1090
  . "$XDG_CONFIG_HOME/shell/env.local.sh"
fi

export PATH
