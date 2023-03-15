#!/bin/bash

VERSION="0.0.1"


pkg_cmd() {
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
  echo Package Manament Tools: $PKG_CMD
}

pkg_cmd