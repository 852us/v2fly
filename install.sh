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
  OS_TYPE=$(awk -F'[="]' '/^ID_LIKE=/{print $2$3}' /etc/os-release)
  echo -e ${CYAN}OS_TYPE=$OS_TYPE${NOCOLOR}
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
  export PKG_CMD=${PKG_CMD:-apt}
}

get_sys_bit() {
  sys_bit=$(uname -m)
  case ${sys_bit} in
  'amd64' | x86_64)
    v2ray_bit="64"
    caddy_arch="amd64"
    ;;
  *aarch64* | *armv8*)
    v2ray_bit="arm64-v8a"
    caddy_arch="arm64"
    ;;
  *)
    echo -e "${RED}不支持现有的体系结构${sys_bit} ... {NOCOLOR}"
    exit 1
    ;;
  esac
  echo -e "${GREEN}支持的体系结构：${sys_bit} ... ${NOCOLOR}"
}

update_os() {
  echo -e "${GREEN}Updating Operating System ...${NOCOLOR}"
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

download_caddy() {
  caddy_repos_url="https://api.github.com/repos/caddyserver/caddy/releases/latest?v=$RANDOM"
  caddy_latest_ver="$(curl -s $caddy_repos_url | grep 'tag_name' | cut -d\" -f4)" # awk -F \" '{print $4}'
  caddy_latest_ver_num=$(echo $caddy_latest_ver | sed 's/v//')
	caddy_tmp="/tmp/install_caddy/"
	caddy_tmp_file="/tmp/install_caddy/caddy.tar.gz"
	caddy_download_link="https://github.com/caddyserver/caddy/releases/download/"
	caddy_download_link="${caddy_download_link}${caddy_latest_ver}/caddy_${caddy_latest_ver_num}_linux_${caddy_arch}.tar.gz"

  echo
	[[ -d $caddy_tmp ]] && rm -rf $caddy_tmp
	if [[ ! ${caddy_arch} ]]; then
		echo -e "${red} 获取 Caddy 下载参数失败！${plain}" && exit 1
	fi
	mkdir -p $caddy_tmp

	if ! wget --no-check-certificate -O "$caddy_tmp_file" $caddy_download_link; then
		echo -e "${red} 下载 Caddy 失败！${plain}" && exit 1
	fi

	tar zxf $caddy_tmp_file -C $caddy_tmp
	cp -f ${caddy_tmp}caddy /usr/local/bin/

	if [[ ! -f /usr/local/bin/caddy ]]; then
		echo -e "${red} 安装 Caddy 出错！${plain}" && exit 1
	fi
}

install_v2fly() {
  :
}

install_caddy() {
  echo
  echo -e "${GREEN}Installing and configuring caddy ...${NOCOLOR}"
  download_caddy
}

verify_root_user
get_pkg_cmd
update_os
install_packages
get_sys_bit
install_v2fly
install_caddy
