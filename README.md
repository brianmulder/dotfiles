# Dotfiles (WSL-first)

This repo is the single source of truth for my WSL dotfiles (Neovim, tmux, shell, git).

The repo is organized into Stow packages (each folder contains files laid out as they should appear in `$HOME`).

## TL;DR (fresh WSL machine)

```bash
sudo apt-get update
sudo apt-get install -y stow zsh tmux xclip ripgrep fd-find curl
cd ~/code/github.com/brianmulder/dotfiles
git submodule update --init --recursive   # tmux TPM is vendored as a submodule
./scripts/install-nvim
./scripts/install-fzf
ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"   # Ubuntu packages fd as fdfind
stow -t "$HOME" shell bash zsh git tmux nvim vim
```

## Setup

Install prerequisites:

```bash
sudo apt-get update
sudo apt-get install -y stow zsh tmux xclip curl
```

Neovim: the current config uses `init.lua` + `lazy.nvim` + `mason.nvim` and requires Neovim >= 0.11 (the Ubuntu 22.04 apt package is too old).

Install the latest Neovim release locally:

```bash
./scripts/install-nvim
```

fzf-lua requires `fzf` >= 0.36 (Ubuntu 22.04 apt ships an older version), so install a recent `fzf` locally:

```bash
./scripts/install-fzf
```

## Apply

From this repo:

```bash
cd ~/code/github.com/brianmulder/dotfiles
stow -t "$HOME" shell bash zsh git tmux nvim vim
```

Notes:
- Stow will fail if a destination file already exists. Move/backup conflicting files first, or use `stow --adopt` (be careful: it moves existing files into the repo).
- For public dotfiles, machine-specific overrides live in untracked local files:
  - `~/.gitconfig.local` (identity/credentials)
  - `~/.config/shell/env.local.sh` (secrets like tokens/API keys)

## What you get (quick tour)

- Shell aliases/helpers shared across bash/zsh: `shell/.config/shell/*`
- `zsh` prompt and completions: `zsh/.zshrc`
- tmux config (XDG) + plugins: `tmux/.config/tmux/tmux.conf`
- Neovim config (Lua) + plugins: `nvim/.config/nvim/init.lua`
- Git defaults + aliases: `git/.gitconfig`

## Git (aliases + views)

Useful aliases from `git/.gitconfig`:
- `git st` (short status)
- `git a` / `git aa` / `git ap` (add helpers)
- `git unstage` (unstage files)
- `git lg` / `git lga` (pretty graph logs)
- `git bv` / `git bva` (informative branch views, newest first)
- `git dc` (diff cached / staged)
- `git cane` (amend, keep message)
- `git pf` (force-with-lease)
- `git po` (push current branch + set upstream)
- `git aliases` (list your git aliases)

Behavior tweaks (intentionally boring/safe):
- `git fetch` prunes deleted branches/tags
- `git pull` is fast-forward only (avoids surprise merge commits)

## Powerline (zsh + tmux + Neovim)

To get “powerline” separators/icons, you need a Nerd Font in Windows Terminal.

1) Install a Nerd Font on Windows (recommended: `JetBrainsMono Nerd Font`).
2) Windows Terminal → Settings → Profiles → Defaults → Appearance → Font face → pick that Nerd Font.
3) Verify glyphs render (should not show squares): `bash ./scripts/powerline-test`

This repo uses:
- zsh: `starship` prompt (optional). Install: `bash ./scripts/install-starship` then restart your shell.
- tmux: a Solarized-ish powerline statusline in `tmux/.config/tmux/tmux.conf`
- Neovim: `lualine.nvim` statusline (installed via `lazy.nvim`)

## Profiling startup (zsh / nvim)

These scripts run tools in a subprocess (safer than launching an interactive shell inside another tool):

```bash
./scripts/profile-zsh-startup

./scripts/profile-nvim-startup
./scripts/profile-nvim-startup --clean
```

## tmux basics (rusty rookie)

tmux uses a “prefix key” (default is `Ctrl-b`) then a command key.

Core pane/window commands (defaults):
- Split vertically (left/right): `Ctrl-b` then `%`
- Split horizontally (top/bottom): `Ctrl-b` then `"`
- Close current pane: `Ctrl-b` then `x`
- Move between panes (vim keys): `Ctrl-b` then `h/j/k/l`
- Move between panes (no prefix): `Alt-h/j/k/l` (if your terminal passes Alt)
- New window: `Ctrl-b` then `c`
- Popup shell: `Ctrl-b` then `P`
- Next/prev window: `Ctrl-b` then `n` / `p`
- Detach from session: `Ctrl-b` then `d`
- Zoom/unzoom pane: `Ctrl-b` then `z`
- List keybindings: `Ctrl-b` then `?`

Copy mode (vi-style; enabled by config):
- Enter copy mode: `Ctrl-b` then `[`
- Move: `h/j/k/l` (or arrows), search with `/`
- Copy selection: press `Space` to start selection, `Enter` to copy (tmux default)
- Also configured: in copy-mode-vi, `y` copies to clipboard (WSL prefers `clip.exe`, falls back to `xclip`)

Sessions:
- List sessions: `tmux ls`
- Attach: `tmux a` (or `tmux a -t name`)
- New named session: `tmux new -s name`

### Saving/restoring sessions (TPM + resurrect/continuum)

This repo enables:
- `tmux-resurrect`: saves/restores tmux sessions
- `tmux-continuum`: auto-saves periodically and can auto-restore

Keys (defaults from tmux-resurrect):
- Save: `Ctrl-b` then `Ctrl-s`
- Restore: `Ctrl-b` then `Ctrl-r`

TPM is vendored in this repo as a git submodule and stowed to:
- `~/.config/tmux/plugins/tpm`

On a new machine, make sure submodules are checked out:
```bash
cd ~/code/github.com/brianmulder/dotfiles
git submodule update --init --recursive
```
Tip: if you’re cloning fresh, `git clone --recurse-submodules …` avoids this step.
Then inside tmux: `Ctrl-b` then `I` (capital i) to install plugins.

Note: tmux plugins installed by TPM live in `~/.tmux/plugins` (outside Stow) and are not committed to this repo.

## Neovim basics (rusty rookie)

Splits:
- Horizontal split: `:split` (or `:sp`)
- Vertical split: `:vsplit` (or `:vsp`)
- Move between splits: `Ctrl-w h/j/k/l` (or `Ctrl-w` then arrow keys)
- Close current split: `:q`

### Find files / grep (fzf-lua)

Leader is `<Space>` in this config:
- Find files: `<Space>ff`
- Live grep: `<Space>fg`
- Buffers: `<Space>fb`

### Literal grep (`rg -F`)

- `:GrepF raw capture` (opens quickfix)
- Note: in Vim’s command-line, `"` starts a comment, so avoid `:grep "raw capture"`; use `:GrepF` or single quotes.

### File tree (NERDTree replacement)

This config uses `nvim-tree` (modern equivalent of NERDTree):
- Toggle tree: `<Space>e`

### Spellcheck (prose)

Spellcheck is enabled by default for `markdown`, `text`, and `gitcommit` buffers.

- Toggle spellcheck: `<Space>ss`
- Personal dictionary: `~/.local/state/nvim/spell/en.utf-8.add`

### Terminal buffers (Codex, shell, etc.)

Codex can already read/edit this repo from your terminal, so this Neovim config intentionally does *not* ship an “AI plugin” wrapper.

Still, it’s handy to run Codex *inside* Neovim sometimes:

- Toggle a floating Codex terminal:
  - `<Space>ac` (or `:Codex`)
- Open a right-hand pane running Codex:
  - `:vsplit | terminal codex`
- Prefer a “floater” outside Neovim? Use tmux’s popup:
  - `Ctrl-b` then `P`, then run `codex`
- If `Ctrl-w` navigation/resizing doesn’t work, you’re probably in terminal input mode:
  - Exit terminal input → Normal mode: `Ctrl-\\ Ctrl-n`
  - Back into terminal input: `i`
- Resize splits:
  - Make right pane thinner/wider: `Ctrl-w <` / `Ctrl-w >`
  - Make current pane shorter/taller: `Ctrl-w -` / `Ctrl-w +`
- Window-local working directory (useful if one split should “live” elsewhere):
  - `:lcd /path/to/dir` (window-local)
  - `:cd /path/to/dir` (global)
  - `:pwd` (show current working directory)

#### Mental model (buffers/windows/selection)

- A *buffer* is the text (usually a file) in memory. A *window* is a pane that shows a buffer. Splits create more windows.
- `:ls` shows your open buffers (`%` current, `#` alternate, `+` modified). Switch with `:b N`, `:bn`, `:bp`, or `Ctrl-^` (alternate).
- Visual selection is a *mode*, not a saved object. Reselect the last selection with `gv`.
- If you see “stuck highlight”: it’s often search highlighting; clear it with `:noh`. (If it’s Visual mode, `Esc` exits.)

### Grammar/style (LTeX)

Grammar/style diagnostics are provided by the `ltex` LSP (via `mason.nvim`) for prose filetypes.

- Install: `:Mason` then install `ltex` (or `:MasonInstall ltex`)
- Applies to: `markdown`, `text`, `gitcommit`

## Troubleshooting

- Neovim plugins not installing: run `nvim --headless "+Lazy! sync" +qa`
- Neovim seems “old”: `command -v nvim` should be `~/.local/bin/nvim`; if not, rerun `./scripts/install-nvim`
- `fd` missing: Ubuntu installs it as `fdfind`; the symlink in the TL;DR makes tools happier.
- If commits have no identity, create `~/.gitconfig.local` (see `~/.gitconfig.local.example`).

## Dotfiles doctor

Run a quick inventory/health check:

```bash
./scripts/dotfiles-doctor
```

## macOS / legacy

Old “flat file” dotfiles live in `legacy/` as historical reference.
