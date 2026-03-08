# Dotfiles agent notes (WSL-first, Windows-friendly)

This repo is the single source of truth for my WSL dotfiles using **GNU Stow**. Native Windows support is additive only: keep the repo WSL-first and use the PowerShell/bootstrap/doctor scripts as a small annex rather than refactoring the whole layout.

## Repo intent

- Prioritize **minimal, low cognitive load** defaults (ADHD-friendly).
- Prefer boring, composable conventions (Zen of Python vibe).
- Prefer **XDG compliance** (`~/.config`, `~/.local/*`) where practical.
- Keep secrets out of git (auth tokens, history logs, keys).

## Layout (Stow packages)

Each top-level folder is a Stow package whose contents mirror `$HOME`:

- `shell/`: shared cross-shell env + aliases + functions (`~/.config/shell/*`)
- `bash/`: bash glue (`~/.bash_aliases`)
- `zsh/`: interactive zsh config (`~/.zshrc`, `~/.zshenv`)
- `tmux/`: tmux config (`~/.tmux.conf` shim + `~/.config/tmux/tmux.conf`)
- `nvim/`: Neovim config (`~/.config/nvim/init.lua`)
- `git/`: git config + ignore (`~/.gitconfig`, `~/.config/git/ignore`)
- `powershell/`: native Windows PowerShell profile (`~/Documents/PowerShell/*`)
- `vim/`: legacy Vim config (`~/.vimrc`)
- `legacy/`: historical macOS-era flat dotfiles (reference only)
- `scripts/`: local bootstrap scripts (e.g. `scripts/install-nvim`)

## Bootstrapping (new machine)

1. Install dependencies: `stow`, `tmux`, `zsh`, `fzf`, `xclip`.
2. Install Neovim **>= 0.11** via `scripts/install-nvim` (Ubuntu apt Neovim is too old).
3. Apply packages from repo root:
   - `stow -t "$HOME" shell bash zsh git tmux nvim vim`

## Important gotchas / context

### Stow adoption

- We used `stow --adopt` to import existing live WSL configs into:
  - `git/.gitconfig`, `vim/.vimrc`, `codex/.codex/config.toml`, `codex/.codex/rules/default.rules`
- Avoid `--adopt` for secret-bearing files unless you explicitly intend to move them into the repo.

### Codex (not tracked)

This repo does not track any `~/.codex/*` config/rules. Keep Codex auth/history local and out of git.

### Native Windows support (additive)

- Native Windows support is PowerShell + `scripts/bootstrap-windows.ps1` + `scripts/dotfiles-doctor-windows.ps1` + small shared-config cleanup. Do not turn the repo into a generic Windows home-manager tree.
- Prefer explicit auditing over magical fixes: use `where.exe` and `Get-Command` for command resolution. In PowerShell, `where` is `Where-Object`, not `where.exe`.
- Do not over-own machine PATH history. Keep changes minimal and focused on the repo-managed seam.

### WSL: Windows PATH shims

- WSL commonly inherits Windows PATH entries. That can cause Windows-installed CLIs to shadow WSL ones.
- Fix: `shell/.config/shell/env.sh` prepends user-local bins and your NVM Node bin early, so Linux CLIs win on PATH.
- If a command is still hashed to a Windows path after switching shells, clear caches: `rehash` (zsh) / `hash -r` (bash).

### WSL runtime dirs and fzf-lua

- Some Neovim plugins (notably `fzf-lua`) rely on a writable `XDG_RUNTIME_DIR`.
- `shell/.config/shell/env.sh` sets a fallback `XDG_RUNTIME_DIR="$XDG_STATE_HOME/run"` when needed.

### Neovim tooling versions

- `fzf-lua` requires `fzf >= 0.36`. Ubuntu 22.04 apt ships an older `fzf`, so we install a modern one to `~/.local/bin` via `scripts/install-fzf`.

### zsh compdump issues

- Earlier, `compinit` tried writing `.zcompdump.*` in `$HOME` and hit permission issues.
- We set `ZSH_COMPDUMP` in `zsh/.zshenv` and use `compinit -i` in `zsh/.zshrc`.
- If non-interactive `zsh -ic` appears to hang, test config with:
  - `zsh -c 'source ~/.zshrc; echo ok'`

### Neovim version + install script

- `scripts/install-nvim` downloads the latest Neovim tarball to `~/.local/nvim` and links `~/.local/bin/nvim`.
- It also creates `~/.local/bin/nvimdiff` as a wrapper script (do not symlink `nvimdiff` to `nvim`; that breaks the binary).

### Powerline/prompt (fonts matter)

- Powerline separators and many icons require a Nerd Font configured in Windows Terminal.
- `scripts/powerline-test` is the fastest sanity check.

### “I ran git status and it says no repo”

- This happened because the interactive session CWD was `/home/brianm/code/local/neovim` (not a git repo).
- Use `cd ~/code/github.com/brianmulder/dotfiles` or `git -C ~/code/github.com/brianmulder/dotfiles …` when operating on the dotfiles repo.

### Approvals and autonomy

- Codex “approvals” are primarily controlled by how Codex is launched (`codex --ask-for-approval …`, `codex --sandbox …`) and by the environment’s sandboxing policy.
- Repo rules (`codex/.codex/rules/*.rules`) can reduce Codex’s own command confirmation prompts, but they cannot override an external harness policy that forces approvals.
- For a low-friction dotfiles workflow, prefer a dedicated launcher command that:
  - pins the working dir to this repo, and
  - uses `--ask-for-approval never` with `--sandbox workspace-write` plus `--add-dir "$HOME"` so `stow` and installers can operate.

## Safety / editing guidance

- Keep changes incremental; favor defaults and a small plugin set.
- Document keymaps and “how to use it” in `README.md` for a rusty future me.
- ShellCheck doesn’t support zsh; lint `scripts/*` and `shell/*` instead of `.zshrc/.zshenv`.
- Prefer adding/adjusting small “doctor” checks when we learn a new failure mode (PATH shadowing, tool version minimums, fonts).
- For any non-trivial change, run the relevant doctor script before and after (`./scripts/dotfiles-doctor` on WSL, `.\scripts\dotfiles-doctor-windows.ps1` on native Windows), and update the doctor/docs when a new gotcha is discovered.

## Guardrails (avoid “hack cliff”)

When troubleshooting slowness or weird behavior, keep these principles:

- **Consistency / least surprise:** avoid “special modes” (e.g. skipping `compinit`/Starship) for common entrypoints like tmux popups; the same action should behave the same everywhere.
- **Root-cause over symptoms:** don’t paper over slowness with flags; first prove what’s slow and why (PATH, shims, filesystem, plugin, etc.).
- **Single source of truth:** don’t fork behavior between tmux bindings and shell config; dotfiles should define one canonical experience.
- **Low cognitive load:** avoid adding toggles/branching unless they’re truly permanent; they create future debugging and “which mode am I in?” friction.
- **Reproducibility first:** lock down measurement conditions before acting (cold/warm cache, consistent env, no tmux-server PATH drift).
- **WSL/tmux environment footguns:** tmux popups run under tmux server env (often different PATH + hashed commands); always verify resolution with `command -v <thing>` / `type -a <thing>` when behavior differs.
