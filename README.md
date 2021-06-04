# Pre-requisistes

# Assumptions

- github.com checked out to ~/code (e.g. ~/code/github.com/brianmulder/dotfiles)

# Recommended

* [Solarized](http://ethanschoonover.com/solarized)

# Installation

## ZSH

```
function install_custom_oh_mh_zsh_additions() {
  repo_dir=$HOME/code/github.com/brianmulder/dotfiles
  mkdir -p $(dirname $repo_dir)
  git clone https://github.com/brianmulder/dotfiles.git $repo_dir
  ln -s $repo_dir/zshrc $HOME/.oh-my-zsh/custom/zshrc.local.zsh
  ln -s $repo_dir/aliases $HOME/.oh-my-zsh/custom/aliases.zsh
}

> install_custom_oh_mh_zsh_additions $HOME/code/github.com/brianmulder/dotfiles
> git clone https://github.com/brianmulder/scripts.git $HOME/code/github.com/brianmulder/scripts
> ln -s $HOME/code/github.com/brianmulder/scripts/functions $HOME/.oh-my-zsh/custom/functions.zsh
```

## gitconfig

Add a stanza similar to the following to your `~/.gitconfig` or equivalent:

```
[include]
  path = ~/code/github.com/brianmulder/dotfiles/gitconfig
```

## VIM

* `> brew install ctags`
* Dotfile: `> ln -s $HOME/code/github.com/brianmulder/dotfiles/vimrc $HOME/.vimrc`

## Tmux

```
> ln -s $HOME/code/github.com/brianmulder/tmux.conf $HOME/.tmux.conf
```


