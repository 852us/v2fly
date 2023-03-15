#!/bin/bash

VERSION="0.0.1"

verify_root_user() {
  if [[ $EUID -ne 0 ]] ; then
    echo
    echo "必须使用root用户"
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
  echo "Updating Operating System .."
  $PKG_CMD update -y
  $PKG_CMD upgrade -y
}


verify_root_user
get_pkg_cmd
update_os
