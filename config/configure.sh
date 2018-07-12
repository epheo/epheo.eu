#!/bin/bash

get_config_files () {
  files=`ls files |grep -v /`
}

symlink () {
  f=''
  for f in $files; do 
    mv ~/.$f /tmp ;\
    ln -s `pwd`/files/$f ~/.$f ;\
    echo "Config file $f symlinked"
  done
}

install_vim () {
  sudo pacman -S --noconfirm vim
  files='vimrc' symlink
  git clone https://github.com/VundleVim/Vundle.vim.git \
            ~/.vim/bundle/vundle
  vim +PluginInstall +qall
}

install_zsh () {
  sudo pacman -S --noconfirm zsh
  files='zshrc zsh_alias' symlink
  echo "sudo sed '/^$user/s/bash/zsh/' /etc/passwd"
  echo "To replace bash with zsh"
}

install_screen () {
  sudo pacman -S --noconfirm screen
  files='screenrc' symlink
}


install_xorg () {
  sudo pacman -S --noconfirm xorg
  files='Xdefaults' symlink
}

install_i3 () {
  install_xorg
  sudo pacman -S --noconfirm i3 i3blocks urxvt qutebrowser
  files='i3blocks.conf' symlink
  mv ~/.config/i3 /tmp ;\
  ln -s `pwd`/files/config/i3 ~/.config/i3 ;\
  echo "Config file .config/i3 symlinked"
}

sudo pacman -Syu
install_vim
install_zsh
install_screen
