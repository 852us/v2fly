#!/bin/bash

VERSION="0.0.1"
RED='\e[91m'
GREEN='\e[92m'
NOCOLOR='\e[0m'

PKG_CMD=""
SYS_BIT=""
V2RAY_BIT=""
CADDY_ARCH=""
PACKAGES="curl git wget unzip"

_exit () {
  echo
  exit $@
}

verify_root_user() {
  if [[ $EUID -ne 0 ]]; then
    echo
    echo -e "${RED}必须使用root用户${NOCOLOR}"
    echo
    _exit 1
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

update_os() {
  echo -e "${GREEN}Updating Operating System ... ${NOCOLOR}"
  $PKG_CMD update -y
  $PKG_CMD upgrade -y
}

install_packages() {
  for pkg in $PACKAGES; do
    echo
    echo -e "${GREEN}$PKG_CMD install $pkg -y ${NOCOLOR}"
    $PKG_CMD install $pkg -y
  done
}

get_SYS_BIT() {
  SYS_BIT=$(uname -m)
  case ${SYS_BIT} in
  'amd64' | x86_64)
    V2RAY_BIT="64"
    CADDY_ARCH="amd64"
    ;;
  *aarch64* | *armv8*)
    V2RAY_BIT="arm64-v8a"
    CADDY_ARCH="arm64"
    ;;
  *)
    echo
    echo -e "${RED}不支持现有的体系结构${SYS_BIT} ... ${NOCOLOR}"
    _exit 1
    ;;
  esac
  echo
  echo -e "${GREEN}支持的体系结构：${SYS_BIT} ... ${NOCOLOR}"
  echo "  CADDY_ARCH: ${CADDY_ARCH}"
  echo "  V2RAY_BIT: ${V2RAY_BIT}"
}

install_caddy() {
  echo
  echo -e "${GREEN}安装Caddy ... ${NOCOLOR}"

  caddy_repos_url="https://api.github.com/repos/caddyserver/caddy/releases/latest?v=$RANDOM"
  caddy_latest_version="$(curl -s $caddy_repos_url | grep 'tag_name' | awk -F '"' '{print $4}')"
  caddy_latest_version_number=${caddy_latest_version/v/}
  caddy_tmp="/tmp/install_caddy/"
  caddy_tmp_file="/tmp/install_caddy/caddy.tar.gz"
  caddy_download_link="https://github.com/caddyserver/caddy/releases/download"
  caddy_download_link="${caddy_download_link}/${caddy_latest_version}/caddy_${caddy_latest_version_number}_linux_${CADDY_ARCH}.tar.gz"

  caddy_current_version=$(caddy version | awk -F ' ' '{print $1}')
  if [[ ${caddy_current_version} == ${caddy_latest_version} ]]; then
    echo -e "${RED}Caddy当前安装版本：${caddy_current_version}，与最新版本：${caddy_latest_version}相同，无需安装 ... ${NOCOLOR}"
    return
  else
    echo -e "${GREEN}Caddy当前安装版本：${caddy_current_version}，与最新版本：${caddy_latest_version}不同，安装最新版 ... ${NOCOLOR}"
  fi

  [[ -d $caddy_tmp ]] && rm -rf $caddy_tmp
  if [[ ! ${CADDY_ARCH} ]]; then
    echo -e "${RED} 获取 Caddy 下载参数失败！${NOCOLOR}"
    _exit 1
  fi
  mkdir -p $caddy_tmp

  if ! wget --no-check-certificate -O "$caddy_tmp_file" $caddy_download_link; then
    echo -e "${RED} 下载 Caddy 失败！${NOCOLOR}"
    _exit 1
  fi

  tar zxf $caddy_tmp_file -C $caddy_tmp
  cp -f ${caddy_tmp}caddy /usr/local/bin/

  if [[ ! -f /usr/local/bin/caddy ]]; then
    echo -e "${red} 安装 Caddy 出错！${NOCOLOR}"
    _exit 1
  fi
}

install_v2fly() {
  echo
  echo -e "${GREEN}安装V2Ray ... ${NOCOLOR}"

  v2ray_repos_url="https://api.github.com/repos/v2fly/v2ray-core/releases/latest?v=$RANDOM"
  v2ray_latest_version=$(curl -s $v2ray_repos_url | grep 'tag_name' | awk -F \" '{print $4}')
  v2ray_latest_version_number=${v2ray_latest_version/v/}
  v2ray_current_version_number=$(v2ray version | awk -F ' ' '/V2Ray/{print $2}')

  v2ray_tmp_file="/tmp/v2ray.zip"
  v2ray_download_link="https://github.com/v2fly/v2ray-core/releases/download/"
  v2ray_download_link="${v2ray_download_link}/${v2ray_latest_version}/v2ray-linux-${V2RAY_BIT}.zip"

  if [[ "${v2ray_current_version_number}" == "${v2ray_latest_version_number}" ]]; then
    echo -e "${RED}V2Ray当前版本：${v2ray_current_version_number}，与最新版本：${v2ray_latest_version_number}相同，无需安装 ... ${NOCOLOR}"
    return 1
  else
    echo -e "${RED}V2Ray当前版本：${v2ray_current_version_number}，与最新版本：${v2ray_latest_version_number}不同，安装最新版本 ... ${NOCOLOR}"
  fi

  if ! wget --no-check-certificate -O "$v2ray_tmp_file" $v2ray_download_link; then
    echo
    echo -e "${RED}下载 V2Ray 失败 ... ${NOCOLOR}"
    _exit 1
  fi

  v2fly_path="/usr/bin/v2fly"
  unzip -o $v2ray_tmp_file -d ${v2fly_path}
  chmod +x ${v2fly_path}/v2ray
  cp ${v2fly_path}/v2ray /usr/bin/v2ray
}

main() {
  verify_root_user
  get_pkg_cmd
  update_os
  install_packages
  get_SYS_BIT
  install_caddy
  install_v2fly
  echo
}

main