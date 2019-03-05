#!/bin/bash

# set -e
# set -x

if grep arch /etc/*-release > /dev/null
then
  os="arch"
  install_command='sudo pacman -S --noconfirm'
  desktop_pkgs="urxvt xorg xpdf viewnior"
fi

if grep fedora /etc/*-release > /dev/null
then
  os="fedora"
  install_command='sudo dnf install -y'
  desktop_pkgs="rxvt-unicode xorg-x11-server-Xorg xorg-x11-server-utils xorg-x11-xinit xpdf viewnior"
fi

symlink () {
  if [ ! -L "/home/$USER/.$file" ]; then
    if [ ! -f "/home/$USER/.$file" ]; then
      ln -s `pwd`/files/$file ~/.$file
      echo "Config file $file is now a symlink"
    else
      mv ~/.$file /tmp
      ln -s `pwd`/files/$file ~/.$file
      echo "Config file $file is now a symlink"
      echo "Original file moved to /tmp"
    fi
  else
    if [ ! -f "/home/$USER/.$file" ];then
      mv ~/.$file /tmp
      ln -s `pwd`/files/$file ~/.$file
    else
      echo "File $file is already a symplink"
    fi
  fi
}

base () {
  $install_command screen
  file='screenrc' symlink
  install_vim
  install_zsh
}

desktop () {
  base
  $install_command i3 qutebrowser $desktop_pkgs
  file='Xdefaults' symlink
  file='i3blocks.conf' symlink
  file='config/mimeapps.list' symlink
  file='config/qutebrowser/config.py' symlink
  file='config/i3/config' symlink
}

install_vim () {
  $install_command vim
  file='vimrc' symlink
  if [ ! -d "/home/$USER/.vim/bundle/vundle" ]; then
    git clone https://github.com/VundleVim/Vundle.vim.git \
              ~/.vim/bundle/vundle
  fi
  vim +PluginInstall +qall
}

install_zsh () {
  $install_command zsh
  file='zshrc' symlink
  file='zsh_alias' symlink
  sudo sed -i "/^$USER/s/bash/zsh/" /etc/passwd
}

case  $1  in
  desktop)
    desktop
    ;;
  server)
    base
    ;; 
  *)
    base
    ;;
esac

