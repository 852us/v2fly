#!/bin/bash

VERSION="0.0.1"
RED='\e[91m'
GREEN='\e[92m'
NOCOLOR='\e[0m'

verify_root_user() {
  if [[ $EUID -ne 0 ]]; then
    echo
    echo -e "${RED}必须使用root用户${NOCOLOR}"
    echo
    exit 1
  fi
}

get_pkg_cmd() {
  OS_TYPE=$(awk -F'[="]' '/^ID_LIKE=/{print $2$3}' /etc/os-release)
  echo -e "${GREEN}OS_TYPE=$OS_TYPE ${NOCOLOR}"
  case $OS_TYPE in
  "debian")
    :
    echo "Debian-like Linux, including Debian and Ubuntu Linux."
    PKG_CMD="apt"
    ;;
  "fedora")
    :
    echo "Fedora-like Linux, including Red Hat, Centos, and Fedora Linux."
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
    echo
    echo -e "${RED}不支持现有的体系结构${sys_bit} ... ${NOCOLOR}"
    exit 1
    ;;
  esac
  echo
  echo -e "${GREEN}支持的体系结构：${sys_bit} ... ${NOCOLOR}"
}

update_os() {
  echo -e "${GREEN}Updating Operating System ... ${NOCOLOR}"
  $PKG_CMD update -y
  $PKG_CMD upgrade -y
}

install_packages() {
  pkgs="curl git wget unzip"
  for pkg in $pkgs; do
    echo
    echo -e "${GREEN}$PKG_CMD install $pkg -y ${NOCOLOR}"
    $PKG_CMD install $pkg -y
  done
}

download_caddy() {
  caddy_repos_url="https://api.github.com/repos/caddyserver/caddy/releases/latest?v=$RANDOM"
  caddy_latest_version="$(curl -s $caddy_repos_url | grep 'tag_name' | awk -F '"' '{print $4}')"
  caddy_latest_version_number=$(echo $caddy_latest_version | sed 's/v//')
  caddy_tmp="/tmp/install_caddy/"
  caddy_tmp_file="/tmp/install_caddy/caddy.tar.gz"
  caddy_download_link="https://github.com/caddyserver/caddy/releases/download"
  caddy_download_link="${caddy_download_link}/${caddy_latest_version}/caddy_${caddy_latest_version_number}_linux_${caddy_arch}.tar.gz"

  caddy_current_version=$(caddy version | sed 's/^v//' | sed 's/ .*//')
  if [[ ${caddy_current_version} == ${caddy_latest_version_number} ]]; then
    echo -e "${RED}Caddy当前安装版本：${caddy_current_version}，与最新版本：${caddy_latest_version_number}相同，无需安装 ... ${NOCOLOR}"
    return
  else
    echo -e "${GREEN}Caddy当前安装版本：${caddy_current_version}，与最新版本：${caddy_latest_version_number}不同，安装最新版 ... ${NOCOLOR}"
  fi

  [[ -d $caddy_tmp ]] && rm -rf $caddy_tmp
  if [[ ! ${caddy_arch} ]]; then
    echo -e "${RED} 获取 Caddy 下载参数失败！${NOCOLOR}"
    exit 1
  fi
  mkdir -p $caddy_tmp

  if ! wget --no-check-certificate -O "$caddy_tmp_file" $caddy_download_link; then
    echo -e "${RED} 下载 Caddy 失败！${NOCOLOR}"
    exit 1
  fi

  tar zxf $caddy_tmp_file -C $caddy_tmp
  cp -f ${caddy_tmp}caddy /usr/local/bin/

  if [[ ! -f /usr/local/bin/caddy ]]; then
    echo -e "${red} 安装 Caddy 出错！${NOCOLOR}"
    exit 1
  fi
}

install_caddy() {
  echo
  echo -e "${GREEN}Installing and configuring caddy ... ${NOCOLOR}"
  download_caddy
}

get_v2flay_latest_version() {
  v2ray_repos_url="https://api.github.com/repos/v2fly/v2ray-core/releases/latest?v=$RANDOM"
  v2ray_latest_version=$(curl -s $v2ray_repos_url | grep 'tag_name' | awk -F \" '{print $4}')
  v2ray_latest_version_number=${v2ray_latest_version/v/}
}

download_v2fly() {
  v2ray_current_version_number=$(/usr/bin/v2fly/v2ray version | awk -F ' ' '/V2Ray/{print $2}')
  [[ ! $v2ray_latest_version ]] && get_v2flay_latest_version
  v2ray_tmp_file="/tmp/v2ray.zip"
  v2ray_download_link="https://github.com/v2fly/v2ray-core/releases/download/"
  v2ray_download_link="${v2ray_download_link}/${v2ray_latest_version}/v2ray-linux-${v2ray_bit}.zip"

  if [[ "${v2ray_current_version_number}" = "${v2ray_latest_version_number}" ]] ; then
    echo -e "${RED}V2Ray当前版本：${v2ray_current_version_number}，与最新版本：${v2ray_latest_version_number}相同，无需安装 ... ${NOCOLOR}"
    return 1
  else
    echo -e "${RED}V2Ray当前版本：${v2ray_current_version_number}，与最新版本：${v2ray_latest_version_number}不同，安装最新版本 ... ${NOCOLOR}"
  fi

  if ! wget --no-check-certificate -O "$v2ray_tmp_file" $v2ray_download_link; then
    echo
    echo -e "${RED}下载 V2Ray 失败 ... ${NOCOLOR}"
    exit 1
  fi

  unzip -o $v2ray_tmp_file -d "/usr/bin/v2fly/"
  chmod +x /usr/bin/v2fly/v2ray
}

install_v2fly() {
  echo
  echo -e "${GREEN}Installing and configuring V2Ray ... ${NOCOLOR}"
  download_v2fly
}

verify_root_user
get_pkg_cmd
update_os
install_packages
get_sys_bit
install_caddy
install_v2fly