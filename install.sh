#!/bin/bash

VERSION="0.0.1"


RED='\e[91m'
GREEN='\e[92m'
YELLOW='\e[93m'
BLUE='\e[94m'
MAGENTA='\e[95m'
CYAN='\e[96m'
NOCOLOR='\e[0m'

verify_root_user() {
  if [[ $EUID -ne 0 ]] ; then
    echo
    echo -e "${RED}必须使用root用户${NOCOLOR}"
    echo
    exit 1
  fi
}

get_pkg_cmd() {
  OS_TYPE=$(awk -F'"' '/^ID_LIKE=/{print $2}' /etc/os-release)
  echo -e ${CYAN}$OS_TYPE${NOCOLOR}
  case $OS_TYPE in
  "debian"):
    echo -e Debian-like Linux, including Debian and Ubuntu Linux.
    PKG_CMD="apt"
    ;;
  "fedora"):
    echo -e Fedora-like Linux, including Red Hat, Centos, and Fedora Linux.
    PKG_CMD="yum"
    ;;
  esac
  echo -e Package Manament Tool: $PKG_CMD
  echo
  export PKG_CMD
}

update_os() {
  echo -e "${GREEN}Updating Operating System ..${NOCOLOR}"
  $PKG_CMD update -y
  $PKG_CMD upgrade -y
}

install_packages() {
  pkgs="curl git wget unzip"
  for pkg in $pkgs; do
    echo
    echo -e "${GREEN}$PKG_CMD install $pkg -y${NOCOLOR}"
    $PKG_CMD install $pkg -y
  done
}

verify_root_user
get_pkg_cmd
update_os
install_packages
