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
    echo "${RED}必须使用root用户${NOCOLOR}"
    echo
  fi
}

get_pkg_cmd() {
  OS_TYPE=$(awk -F'"' '/^ID_LIKE=/{print $2}' /etc/os-release)
  case $OS_TYPE in
  "debian"):
    echo Debian-like Linux, including Debian and Ubuntu Linux.
    PKG_CMD="apt"
    ;;
  "fedora"):
    echo Fedora-like Linux, including Red Hat, Centos, and Fedora Linux.
    PKG_CMD="yum"
    ;;
  esac
  echo Package Manament Tool: $PKG_CMD
  echo
}

update_os() {
  echo "${CYAN}Updating Operating System ..${NOCOLOR}"
  $PKG_CMD update -y
  $PKG_CMD upgrade -y
}


verify_root_user
get_pkg_cmd
update_os
