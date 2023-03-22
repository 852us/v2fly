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
V2FLY_PATH="/usr/local/bin/v2fly"
V2RAY="/usr/local/bin/v2ray"
CADDY="/usr/local/bin/caddy"


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

  CADDY_URL="https://api.github.com/repos/caddyserver/caddy/releases/latest?v=$RANDOM"
  CADDY_LATEST_VERSION="$(curl -s $CADDY_URL | grep 'tag_name' | awk -F '"' '{print $4}')"
  CADDY_LATEST_VERSION_NUMBER=${CADDY_LATEST_VERSION/v/}
  CADDY_TEMP_PATH="/tmp/install_caddy"
  CADDY_TEMP_FILE="${CADDY_TEMP_PATH}/caddy.tar.gz"
  CADDY_DOWNLOAD_URL="https://github.com/caddyserver/caddy/releases/download"
  CADDY_DOWNLOAD_URL="${CADDY_DOWNLOAD_URL}/${CADDY_LATEST_VERSION}/caddy_${CADDY_LATEST_VERSION_NUMBER}_linux_${CADDY_ARCH}.tar.gz"

  caddy_current_version=$(caddy version | awk -F ' ' '{print $1}')
  if [[ ${caddy_current_version} == ${CADDY_LATEST_VERSION} ]]; then
    echo -e "${RED}Caddy当前安装版本：${caddy_current_version}，与最新版本：${CADDY_LATEST_VERSION}相同，无需安装 ... ${NOCOLOR}"
    return 1
  fi

  if [[ ! ${CADDY_ARCH} ]]; then
    echo -e "${RED}获取 Caddy 下载参数失败！${NOCOLOR}"
    _exit 1
  fi
  [[ -d ${CADDY_TEMP_PATH} ]] && rm -rf ${CADDY_TEMP_PATH}
  mkdir -p ${CADDY_TEMP_PATH}

  if ! wget --no-check-certificate -O "$CADDY_TEMP_FILE" $CADDY_DOWNLOAD_URL; then
    echo -e "${RED}下载 Caddy 失败！${NOCOLOR}"
    _exit 1
  fi

  tar zxf ${CADDY_TEMP_FILE} -C ${CADDY_TEMP_PATH}
  cp -f ${CADDY_TEMP_PATH}/caddy ${CADDY}
  [[ -d ${CADDY_TEMP_PATH} ]] && rm -rf ${CADDY_TEMP_PATH}

  if [[ ! -f ${CADDY} ]]; then
    echo -e "${RED}安装 Caddy 出错！${NOCOLOR}"
    _exit 1
  fi
}

uninstall_caddy() {
  echo
  echo -e "${RED}正在卸载Caddy ... ${NOCOLOR}"

  [[ -f ${V2RAY} ]] && rm -f ${V2RAY}
  [[ -d ${V2FLY_PATH} ]] && rm -rf ${V2FLY_PATH}
  [[ -f ${CADDY} ]] && rm -f ${CADDY}
  echo -e "${RED}完成Caddy卸载 ${NOCOLOR}"
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
  fi

  if ! wget --no-check-certificate -O "$v2ray_tmp_file" $v2ray_download_link; then
    echo
    echo -e "${RED}下载 V2Ray 失败 ... ${NOCOLOR}"
    _exit 1
  fi

  unzip -o $v2ray_tmp_file -d ${V2FLY_PATH}
  chmod +x ${V2FLY_PATH}/v2ray
  cp ${V2FLY_PATH}/v2ray ${V2RAY}
}

uninstall_v2fly() {
  echo
  echo -e "${RED}正在卸载V2Ray ... ${NOCOLOR}"

  [[ -f ${V2RAY} ]] && rm -f ${V2RAY}
  [[ -d ${V2FLY_PATH} ]] && rm -rf ${V2FLY_PATH}
  echo -e "${RED}完成V2Ray卸载 ${NOCOLOR}"
}

main() {
  verify_root_user
  get_pkg_cmd
  update_os
  install_packages
  get_SYS_BIT
  install_caddy
  install_v2fly
  uninstall_caddy
  uninstall_v2fly
  echo
}

main