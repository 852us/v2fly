#!/bin/bash

VERSION="0.0.1"


pkg_cmd() {
  OS_TYPE=$(awk -F'"' '/^ID_LIKE=/{print $2}' /etc/os-release)
  echo $OS_TYPE
  case $OS_TYPE in
  "debian"):
    echo Debian-like Linux, including Debian and Ubuntu Linux.
    ;;
  "fedora"):
    echo Fedora-like Linux, including Red Hat, Centos, and Fedora Linux.
    ;;
  esac
}

pkg_cmd