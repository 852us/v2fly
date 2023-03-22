#!/bin/bash

VERSION="0.0.1"
RED='\e[91m'
GREEN='\e[92m'
CYAN='\e[96m'
NOCOLOR='\e[0m'

PKG_CMD=""
SYS_BIT=""
V2RAY_BIT=""
CADDY_ARCH=""
PACKAGES="curl git wget unzip"
V2FLY_PATH="/usr/local/bin/v2fly"
V2RAY="/usr/local/bin/v2ray"
CADDY="/usr/local/bin/caddy"
CADDY_CONFIG_PATH="/etc/caddy"
CADDY_CONFIG_FILE="${CADDY_CONFIG_PATH}/Caddyfile"
CADDY_SERVICE_FILE="/lib/systemd/system/caddy.service"
V2RAY_CONFIG_PATH="/etc/v2ray"
V2RAY_CONFIG_FILE="${V2RAY_CONFIG_PATH}/config.json"
V2RAY_LOG_PATH="/var/log/v2ray"
V2RAY_SERVICE_FILE="/lib/systemd/system/v2ray.service"

MAGIC_URL="852us.com"
DOMAIN=""
FAKE_DOMAIN="https://www.gnu.org"
FLOW_PATH="/api"
V2RAY_PORT="12345"
PROTOCOL="vmess"
TRANSPORT="ws" # WebSocket
UUID=$(uuidgen -r)
VMESS_FILE="${V2RAY_CONFIG_PATH}/vmess.json"
LOCAL_IP=$(curl -s "https://ifconfig.me")

_exit() {
  echo
  exit $@
}

error() {
  red "输入错误，请重新输入正确的内容 ..."
}

green() {
  echo -e "${GREEN}$@ ${NOCOLOR}"
}

red() {
  echo -e "${RED}$@ ${NOCOLOR}"
}

cyan() {
  echo -e "${CYAN}$@ ${NOCOLOR}"
}

verify_root_user() {
  if [[ $EUID -ne 0 ]]; then
    echo
    red "必须使用root用户"
    echo
    _exit 1
  fi
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
    red "不支持现有的体系结构${SYS_BIT} ... "
    _exit 1
    ;;
  esac
  echo
  green "支持的体系结构：${SYS_BIT} ... "
  echo "  CADDY_ARCH: ${CADDY_ARCH}"
  echo "  V2RAY_BIT: ${V2RAY_BIT}"
}

get_pkg_cmd() {
  OS_TYPE=$(awk -F'[="]' '/^ID_LIKE=/{print $2$3}' /etc/os-release)
  green "OS_TYPE=$OS_TYPE "
  case $OS_TYPE in
  "debian")
    echo "Debian-like Linux, including Debian and Ubuntu Linux."
    PKG_CMD="apt"
    ;;
  "fedora")
    echo "Fedora-like Linux, including Red Hat, Centos, and Fedora Linux."
    PKG_CMD="yum"
    ;;
  esac
  echo "Package Manament Tool: $PKG_CMD"
  echo
  export PKG_CMD=${PKG_CMD:-apt}
}

update_os() {
  green "Updating Operating System ... "
  $PKG_CMD update -y
  $PKG_CMD upgrade -y
}

install_packages() {
  echo
  green "$PKG_CMD install -y ${PACKAGES} "
  $PKG_CMD install -y ${PACKAGES}
}

set_timezone() {
  echo
  timedatectl set-timezone Asia/Shanghai
  timedatectl set-ntp true
  green "已将你的主机设置为Asia/Shanghai时区并通过systemd-timesyncd自动同步时间。"
  echo
}

install_caddy() {
  echo
  green "安装Caddy ... "

  CADDY_URL="https://api.github.com/repos/caddyserver/caddy/releases/latest?v=$RANDOM"
  CADDY_LATEST_VERSION="$(curl -s $CADDY_URL | grep 'tag_name' | awk -F '"' '{print $4}')"
  CADDY_LATEST_VERSION_NUMBER=${CADDY_LATEST_VERSION/v/}
  CADDY_TEMP_PATH="/tmp/install_caddy"
  CADDY_TEMP_FILE="${CADDY_TEMP_PATH}/caddy.tar.gz"
  CADDY_DOWNLOAD_URL="https://github.com/caddyserver/caddy/releases/download"
  CADDY_DOWNLOAD_URL="${CADDY_DOWNLOAD_URL}/${CADDY_LATEST_VERSION}/caddy_${CADDY_LATEST_VERSION_NUMBER}_linux_${CADDY_ARCH}.tar.gz"
  CADDY_CURRENT_VERSION=""

  [[ -f ${CADDY} ]] && CADDY_CURRENT_VERSION=$(caddy version | awk -F' ' '{print $1}')
  if [[ ${CADDY_CURRENT_VERSION} == ${CADDY_LATEST_VERSION} ]]; then
    red "Caddy当前版本：${CADDY_CURRENT_VERSION}，与最新版本：${CADDY_LATEST_VERSION}相同，无需安装 ... "
    return 1
  fi

  if [[ ! ${CADDY_ARCH} ]]; then
    red "获取 Caddy 下载参数失败！"
    _exit 1
  fi
  [[ -d ${CADDY_TEMP_PATH} ]] && rm -rf ${CADDY_TEMP_PATH}
  mkdir -p ${CADDY_TEMP_PATH}

  if ! wget --no-check-certificate -O "$CADDY_TEMP_FILE" $CADDY_DOWNLOAD_URL; then
    red "下载 Caddy 失败！"
    _exit 1
  fi

  tar zxf ${CADDY_TEMP_FILE} -C ${CADDY_TEMP_PATH}
  cp -f ${CADDY_TEMP_PATH}/caddy ${CADDY}
  [[ -d ${CADDY_TEMP_PATH} ]] && rm -rf ${CADDY_TEMP_PATH}

  if [[ ! -f ${CADDY} ]]; then
    red "安装 Caddy 出错！"
    _exit 1
  fi
}

install_v2ray() {
  echo
  green "安装V2Ray ... "

  V2RAY_URL="https://api.github.com/repos/v2fly/v2ray-core/releases/latest?v=$RANDOM"
  V2RAY_LATEST_VERSION=$(curl -s ${V2RAY_URL} | grep 'tag_name' | awk -F \" '{print $4}')
  V2RAY_LATEST_VERSION_NUMBER=${V2RAY_LATEST_VERSION/v/}

  V2RAY_TEMP_FILE="/tmp/v2ray.zip"
  V2RAY_DOWNLOAD_URL="https://github.com/v2fly/v2ray-core/releases/download/"
  V2RAY_DOWNLOAD_URL="${V2RAY_DOWNLOAD_URL}/${V2RAY_LATEST_VERSION}/v2ray-linux-${V2RAY_BIT}.zip"

  [[ -f ${V2RAY} ]] && V2RAY_CURRENT_VERSION_NUMBER="$(v2ray version | awk -F ' ' '/V2Ray/{print $2}')"
  if [[ ${V2RAY_CURRENT_VERSION_NUMBER} == ${V2RAY_LATEST_VERSION_NUMBER} ]]; then
    red "V2Ray当前版本：${V2RAY_CURRENT_VERSION_NUMBER}，与最新版本：${V2RAY_LATEST_VERSION_NUMBER}相同，无需安装 ... "
    return 1
  fi

  if ! wget --no-check-certificate -O "$V2RAY_TEMP_FILE" $V2RAY_DOWNLOAD_URL; then
    echo
    red "下载 V2Ray 失败 ... "
    _exit 1
  fi

  unzip -o $V2RAY_TEMP_FILE -d ${V2FLY_PATH}
  chmod +x ${V2FLY_PATH}/v2ray
  cp ${V2FLY_PATH}/v2ray ${V2RAY}
  [[ -f ${V2RAY_TEMP_FILE} ]] && rm -f ${V2RAY_TEMP_FILE}
}

rm_files() {
  for f in $@; do
    if [[ -f $f ]]; then
      echo rm -f $f
      rm -f $f
    fi
  done
}

rm_dirs() {
  for d in $@; do
    if [[ -d $d ]]; then
      echo rm -rf $d
      rm -rf $d
    fi
  done
}

uninstall_caddy() {
  echo
  if [[ ! -f ${CADDY} ]]; then
    red "未安装Caddy，无需卸载 ... "
  else
    systemctl stop caddy
    systemctl disable caddy
    rm_files "${CADDY}" "${CADDY_SERVICE_FILE}"
    rm_dirs "${CADDY_CONFIG_PATH}"
    red "已卸载Caddy "
  fi
}

uninstall_v2ray() {
  echo
  if [[ ! -f ${V2RAY} ]]; then
    red "未安装V2Ray，无需卸载 ... "
  else
    systemctl stop v2ray
    systemctl disable v2ray
    rm_files ${V2RAY} ${V2RAY_SERVICE_FILE}
    rm_dirs ${V2FLY_PATH} ${V2RAY_CONFIG_PATH} ${V2RAY_LOG_PATH}
    red "已卸载V2Ray "
  fi
}

config_domain() {
  while :; do
    echo
    red "请输入一个已经通过DNS解析到当前主机IP：${IP}的域名！"
    read -p "(例如：${MAGIC_URL}): " DOMAIN
    if [ -z "${DOMAIN}" ]; then
      red "输入的域名为空，重来 ..."
      continue
    fi

    echo
    green "输入的域名：${DOMAIN} "
    DOMAIN_IP=$(dig ${DOMAIN} | grep "^${DOMAIN}" | awk '{print $5}')
    if [[ "${DOMAIN_IP}" != "${LOCAL_IP}" ]]; then
      red "${DOMAIN}: ${DOMAIN_IP}，本地IP：${LOCAL_IP}，输入的域名未正确解析到当前主机 ... "
      continue
    else
      green "${DOMAIN}: ${DOMAIN_IP}，本地IP：${LOCAL_IP}，输入的域名已正确解析到当前主机 ... "
      break
    fi
  done
}

config_caddy() {
  if [[ -d ${CADDY_CONFIG_PATH} ]]; then
    rm -rf ${CADDY_CONFIG_PATH}
  fi
  mkdir -p ${CADDY_CONFIG_PATH}/sites

  cat >${CADDY_CONFIG_FILE} <<-EOF
${DOMAIN} {
  reverse_proxy ${FAKE_DOMAIN} {
    header_up Host {upstream_hostport}
    header_up X-Forwarded-Host {host}
  }
  handle_path ${FLOW_PATH} {
    reverse_proxy 127.0.0.1:${V2RAY_PORT}
  }
}
import sites/*
EOF
  green "Caddy已正确配置 ... "
}

config_v2ray() {
  if [[ -d ${V2RAY_CONFIG_PATH} ]]; then
    rm -rf ${V2RAY_CONFIG_PATH}
  fi
  mkdir -p ${V2RAY_CONFIG_PATH}

  cat >${V2RAY_CONFIG_FILE} <<-EOF
{
  "log": {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": ${V2RAY_PORT},
      "protocol": "${PROTOCOL}",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "level": 1,
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIP"
      },
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ]
}
EOF
}

config() {
  config_domain
  config_caddy
  config_v2ray
  make_vmess
}

install_caddy_service() {
  echo
  green "Caddy服务安装进行中 ..."
  cat >${CADDY_SERVICE_FILE} <<-EOF
# Refer to: https://github.com/caddyserver/dist/blob/master/init/caddy.service
# CADDY_SERVICE_FILE="/lib/systemd/system/caddy.service"
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=root
Group=root
ExecStart=/usr/local/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /etc/caddy/Caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full

[Install]
WantedBy=multi-user.target
EOF

  check_services_status
  if [ ${CADDY_PID} ]; then
    systemctl daemon-reload
  fi
  systemctl enable caddy
  systemctl restart caddy
  green "Caddy服务安装已完成 ..."
}

install_v2ray_service() {
  echo
  green "V2Ray服务安装进行中 ..."
  if [[ -d ${V2RAY_LOG_PATH} ]] ; then
    rm -rf ${V2RAY_LOG_PATH}
  fi
  mkdir -p ${V2RAY_LOG_PATH}
  cat >${V2RAY_SERVICE_FILE} <<-EOF
[Unit]
Description=V2Ray Service
Documentation=https://www.v2fly.org/
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
Environment="V2RAY_VMESS_AEAD_FORCED=false"
NoNewPrivileges=true
ExecStart=/usr/bin/env v2ray.vmess.aead.forced=false ${V2RAY} run -config ${V2RAY_CONFIG_FILE}
Restart=on-failure
StartLimitBurst=0
LimitNOFILE=1048576
LimitNPROC=512

[Install]
WantedBy=multi-user.target
EOF

  check_services_status
  if [ ${V2RAY_PID} ]; then
    systemctl daemon-reload
  fi
  systemctl enable v2ray
  systemctl restart v2ray

  green "V2Ray服务安装已完成 ..."
}

install_services() {
  install_caddy_service
  install_v2ray_service
}

check_services_status() {
  sleep 2s
  V2RAY_PID=$(pgrep -f ${V2RAY})
  CADDY_PID=$(pgrep -f ${CADDY})

  if [ ${V2RAY_PID} ]; then
    V2RAY_STATUS="${GREEN}正在运行${NOCOLOR}"
  else
    V2RAY_STATUS="${RED}未运行${NOCOLOR}"
  fi
  if [ ${CADDY_PID} ]; then
    CADDY_STATUS="${GREEN}正在运行${NOCOLOR}"
  else
    CADDY_STATUS="${RED}未运行${NOCOLOR}"
  fi
}

show_service_status() {
  echo
  echo "检测V2Ray与Caddy服务的状态 ... "
  check_services_status
  echo
  echo -e "V2Ray 状态: $V2RAY_STATUS  /  Caddy 状态: $CADDY_STATUS ${NOCOLOR}"
  echo
}

restart_services() {
  echo
  red "停止Caddy与V2Ray服务"
  systemctl stop caddy v2ray
  show_service_status
  green "启动Caddy与V2Ray服务"
  systemctl start caddy v2ray
  show_service_status
}

prepare_system() {
  get_pkg_cmd
  update_os
  install_packages
  set_timezone
}

install() {
  get_SYS_BIT
  install_caddy
  install_v2ray
  config
  install_services
  show_service_status
  show_info
}

uninstall() {
  uninstall_caddy
  uninstall_v2ray
  show_service_status
}

make_vmess(){
  cat >${VMESS_FILE} <<-EOF
{
  "v": "2",
  "ps": "${DOMAIN}",
  "add": "${DOMAIN}",
  "port": "443",
  "id": "${UUID}",
  "aid": "0",
  "net": "${TRANSPORT}",
  "type": "none",
  "host": "${DOMAIN}",
  "path": "${FLOW_PATH}",
  "tls": "tls"
}
EOF
}

get_info_from_vmess() {
  VMESS_PS=$(awk -F '"' '/"ps"/{print $4}' ${VMESS_FILE})
  VMESS_ADD=$(awk -F '"' '/"add"/{print $4}' ${VMESS_FILE})
  VMESS_PORT=$(awk -F '"' '/"port"/{print $4}' ${VMESS_FILE})
  VMESS_ID=$(awk -F '"' '/"id"/{print $4}' ${VMESS_FILE})
  VMESS_AID=$(awk -F '"' '/"aid"/{print $4}' ${VMESS_FILE})
  VMESS_NET=$(awk -F '"' '/"net"/{print $4}' ${VMESS_FILE})
  VMESS_HOST=$(awk -F '"' '/"host"/{print $4}' ${VMESS_FILE})
  VMESS_PATH=$(awk -F '"' '/"path"/{print $4}' ${VMESS_FILE})
  VMESS_TLS=$(awk -F '"' '/"tls"/{print $4}' ${VMESS_FILE})
}

show_info() {
  if [[ ! -f ${V2RAY_CONFIG_PATH}/vmess.json ]]; then
    red "${V2RAY_CONFIG_PATH}/vmess.json 文件不存在 ..."
  else
    get_info_from_vmess
    VMESS_URL_TEXT="vmess://${VMESS_NET}+${VMESS_TLS}:${VMESS_ID}-${VMESS_AID}@${DOMAIN}:${VMESS_PORT}"
    VMESS_URL_TEXT="${VMESS_URL_TEXT}/?host=${VMESS_HOST}&path=${VMESS_PATH}&tlsServerName=${VMESS_ADD}#${VMESS_PS}"
    VMESS_URL_BASE64="vmess://$(base64 -w 0 ${VMESS_FILE})"

    echo
    echo "-------------------- 配置信息 --------------------"
    cat ${VMESS_FILE}
    echo
    echo "-------------------- V2Ray vmess URL Base 64 --------------------"
    cyan ${VMESS_URL_BASE64}
    echo
    echo "-------------------- V2Ray vmess URL Text --------------------"
    green ${VMESS_URL_TEXT}
    echo
  fi
}

show_menu() {
  while :; do
    echo
    red "V2ray一键安装脚本：${VERSION} "
    echo
    green " 1. 全新安装：更新操作系统、安装 V2Ray与Caddy "
    echo
    green " 2. 安装 V2Ray与Caddy"
    echo
    green " 3. 卸载Caddy与V2Ray "
    echo
    green " 4. 重启Caddy与V2Ray服务"
    echo
    green " 5. 查看配置信息"
    echo

    read -p "$(echo 请选择[1-5]:)" choose
    case $choose in
    1)
      prepare_system
      install
      break
      ;;
    2)
      install
      break
      ;;
    3)
      uninstall
      break
      ;;
    4)
      restart_services
      break
      ;;
    5)
      show_info
      break
      ;;
    *)
      error
      ;;
    esac
  done
  echo
}

show_help() {
  green "V2Ray一键安装脚本 ...

  $0 i | install: 安装 V2Ray与Caddy

  $0 I | install_all: 更新操作系统、安装必要模块、安装 V2Ray与Caddy

  $0 info: 显示客户端连接信息

  $0 m | menu: 管理 V2Ray (同等于直接输入 $0)

  $0 r | restart: 重启 V2Ray与Caddy服务

  $0 u | uninstall: 卸载 V2Ray

  $0 h | help: 显示本帮助信息
  "
}

main() {
  verify_root_user
  args=$1
  [ -z $1 ] && args="menu"
  case $args in
  i | install)
    install
    ;;
  I | install_all)
    prepare_system
    install
    ;;
  info)
    show_info
    ;;
  m | menu)
    show_menu
    ;;
  r | restart)
    restart_services
    ;;
  s | status)
    show_service_status
    ;;
  u | uninstall)
    uninstall
    ;;
  h | help | *)
    show_help $0
    ;;
  esac
}

main $@
