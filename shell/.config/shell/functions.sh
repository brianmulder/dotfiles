#!/usr/bin/env sh

# Small, portable helpers. Keep this file boring.

cd_repo() {
  root="${CODE_DIR:-$HOME/code}"
  if [ ! -d "$root" ]; then
    printf "cd_repo: %s does not exist\n" "$root" >&2
    return 1
  fi

  if command -v fzf >/dev/null 2>&1; then
    selected="$(
      find "$root" -maxdepth 6 -type d -name ".git" -print 2>/dev/null \
        | sed 's#/.git$##' \
        | sed "s#^$root/##" \
        | sort -u \
        | fzf --prompt='repo> ' --height=40% --layout=reverse
    )"
    [ -n "$selected" ] && cd "$root/$selected" || return 0
    return 0
  fi

  cd "$root" || return
}
