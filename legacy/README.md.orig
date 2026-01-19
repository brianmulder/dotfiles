# Pre-requisistes

* [oh-my-zsh](https://github.com/robbyrussell/oh-my-zsh)
* [Inconsolata for Powerline.otf](https://github.com/powerline/fonts/blob/master/Inconsolata/Inconsolata%20for%20Powerline.otf)
* [powerlines](http://powerline.readthedocs.io/en/master/installation.html)

# Assumptions

This scheme for your git repositories:
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

> install_custom_oh_mh_zsh_additions $HOME/github.com/brianmulder/dotfiles
> git clone https://github.com/brianmulder/scripts.git $HOME/github.com/brianmulder/scripts
> ln -s $HOME/github.com/brianmulder/scripts/functions $HOME/.oh-my-zsh/custom/functions.zsh
```

*NB*: If you want powerlines, in file `~/.zshrc` set `ZSH_THEME=agnoster` before `oh-my-zsh` is sourced.
See: https://github.com/robbyrussell/oh-my-zsh/wiki/Themes

## gitconfig

Add a stanza similar to the following to your `~/.gitconfig` or equivalent:

```
[include]
  path = ~/github.com/brianmulder/dotfiles/gitconfig.local
```

## vimwiki

```
> mkdir ~/.vim/pathogens && git clone https://github.com/vimwiki/vimwiki.git ~/.vim/pathogens/vimwiki`
> ln -s $HOME/Dropbox/vimwiki $HOME/vimwiki
```

## VIM

* `> brew install ctags`
* [Stack](http://docs.haskellstack.org/en/stable/README/#how-to-install)
* [haskell-vim-now](https://github.com/begriffs/haskell-vim-now)
* Pathogen: `> curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim`
* Dotfile: `> ln -s $HOME/github.com/brianmulder/dotfiles/vimrc.local $HOME/.config/haskell-vim-now/vimrc.local`

## Tmux

```
> ln -s $HOME/github.com/brianmulder/tmux.conf.local $HOME/.tmux.conf
```

# TODO

- Custom autocorrect, thefuck, rules, see: https://github.com/nvbn/thefuck#settings

