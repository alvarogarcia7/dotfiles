# Source: https://github.com/holman/dotfiles/blob/bca0de21ee89eb634526774cfd157e72e1422231/script/bootstrap
# Attribution: Zach Holman (@holman) and contributors
#!/usr/bin/env bash
#
# bootstrap installs things.

original_folder=$(pwd -P)
cd "$(dirname "$0")/.."
DOTFILES_ROOT=$(pwd -P)

set -e

echo ''

info () {
  printf "\r  [ \033[00;34m..\033[0m ] $1\n"
}

user () {
  printf "\r  [ \033[0;33m??\033[0m ] $1\n"
}

success () {
  printf "\r\033[2K  [ \033[00;32mOK\033[0m ] $1\n"
}

fail () {
  printf "\r\033[2K  [\033[0;31mFAIL\033[0m] $1\n"
  echo ''
  exit
}

link_file () {
  local src=$1 dst=$2

  local overwrite= backup= skip=
  local action=

  if [ -f "$dst" -o -d "$dst" -o -L "$dst" ]
  then

    if [ "$overwrite_all" == "false" ] && [ "$backup_all" == "false" ] && [ "$skip_all" == "false" ]
    then

      local currentSrc="$(readlink $dst)"

      if [ "$currentSrc" == "$src" ]
      then

        skip=true;

      else

        user "File already exists: $dst ($(basename "$src")), what do you want to do?\n\
        [s]kip, [S]kip all, [o]verwrite, [O]verwrite all, [b]ackup, [B]ackup all?"
        read -n 1 action

        case "$action" in
          o )
            overwrite=true;;
          O )
            overwrite_all=true;;
          b )
            backup=true;;
          B )
            backup_all=true;;
          s )
            skip=true;;
          S )
            skip_all=true;;
          * )
            ;;
        esac

      fi

    fi

    overwrite=${overwrite:-$overwrite_all}
    backup=${backup:-$backup_all}
    skip=${skip:-$skip_all}

    if [ "$overwrite" == "true" ]
    then
      rm -rf "$dst"
      success "removed $dst"
    fi

    if [ "$backup" == "true" ]
    then
      mv "$dst" "${dst}.backup"
      success "moved $dst to ${dst}.backup"
    fi

    if [ "$skip" == "true" ]
    then
      success "skipped $src"
    fi
  fi

  if [ "$skip" != "true" ]  # "false" or empty
  then
    ln -s "$1" "$2"
    success "linked $1 to $2"
  fi
}

install_sublime (){

  info 'installing sublime configuration (As of 2020-05, not tested)'
  cd ~/.config/sublime-text-3/Packages
  mv User User_backup || true #this folder might not exist
  ln -s ~/dotfiles/sublime/ User
}

install_dotfiles () {
  info 'installing dotfiles'

  local overwrite_all=false backup_all=false skip_all=false

  for src in $(find -H "$DOTFILES_ROOT" -maxdepth 3 -name '*.symlink' -not -path '*.git*')
  do
    echo "found $src"
    dst="$HOME/.$(basename "${src%.*}")"
    link_file "$src" "$dst"
  done
}

install_binfiles () {
  info 'installing bin files'

  local overwrite_all=false backup_all=false skip_all=false

  set +e
  mkdir "$HOME/bin"
  set -e

  for src in $(find -H "$original_folder/bin" -maxdepth 1 -not -path '*.git*')
  do
    echo "found $src"
    dst="$HOME/bin/$(basename "${src}")"
    link_file "$src" "$dst"
  done
}

install_dotfiles
install_binfiles

install_sublime

echo ''
echo '  All installed!'
