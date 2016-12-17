# Pre-requisistes

* [oh-my-zsh](https://github.com/robbyrussell/oh-my-zsh)
* [Inconsolata for Powerline.otf](https://github.com/powerline/fonts/blob/master/Inconsolata/Inconsolata%20for%20Powerline.otf)
* [powerlines](http://powerline.readthedocs.io/en/master/installation.html)

# Assumptions

This scheme with your git repositories:
```
  $HOME/(domain)/(org|user)/(repo)
  # Example: $HOME/github.com/brianmulder/dotfiles
```

# Recommended

* [Solarized](http://ethanschoonover.com/solarized)

# Installation

## ZSH

```
function install_custom_oh_mh_zsh_additions() {
  repo_dir=$1
  mkdir -p $(dirname $repo_dir)
  git clone https://github.com/brianmulder/dotfiles.git $repo_dir
  ln -s $repo_dir/zshrc.local $HOME/.oh-my-zsh/custom/zshrc.local.zsh
  ln -s $repo_dir/aliases $HOME/.oh-my-zsh/custom/aliases.zsh
}
install_custom_oh_mh_zsh_additions $HOME/github.com/brianmulder/dotfiles
git clone https://github.com/brianmulder/scripts.git $HOME/github.com/brianmulder/scripts
ln -s $HOME/github.com/brianmulder/scripts/functions $HOME/.oh-my-zsh/custom/functions.zsh
```

*NB*: If you want powerlines, in file `~/.zshrc` set `ZSH_THEME=agnoster` before `oh-my-zsh` is sourced.
See: https://github.com/robbyrussell/oh-my-zsh/wiki/Themes

## VIM

* `brew install ctags`
* [Stack](http://docs.haskellstack.org/en/stable/README/#how-to-install)
* [haskell-vim-now](https://github.com/begriffs/haskell-vim-now)
* ... pathogen, NERDTree, vimwiki, cscope...

# TODO

- tmux
- vim
- vimwiki
- pretty (solarized/inconsalata)
- ssh / security

## Machine Profiles

The idea of a 'profile' for the machine pulling down the dotfiles
  -> personal,work,etc
- Affects which wiki's to pull down or are available
- only personal has dropbox
- Github configuration/identity could be different
- zshrc would be parameterised by the set of 'extra' functions and environments sourced into each session

## True Crypt or something to help with security automation
