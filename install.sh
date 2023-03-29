#!/bin/bash

VERSION="v0.1.1"
RED='\e[91m'
GREEN='\e[92m'
CYAN='\e[96m'
NOCOLOR='\e[0m'

PKG_CMD=""
SYS_BIT=""
V2RAY_BIT=""
CADDY_ARCH=""
PACKAGES="curl git wget unzip"
V2FLY_PATH="/usr/bin/v2fly"
V2FLY="/usr/local/sbin/v2fly"
V2RAY="/usr/local/bin/v2ray"
CADDY="/usr/local/bin/caddy"
CADDY_CONFIG_PATH="/etc/caddy"
CADDY_CONFIG_FILE="${CADDY_CONFIG_PATH}/Caddyfile"
CADDY_SERVICE_FILE="/lib/systemd/system/caddy.service"
V2RAY_CONFIG_PATH="/etc/v2ray"
V2RAY_CONFIG_FILE="${V2RAY_CONFIG_PATH}/config.json"
V2RAY_LOG_PATH="/var/log/v2ray"
V2RAY_SERVICE_FILE="/lib/systemd/system/v2ray.service"
V2FLY_VERSION="$(test -f ${V2FLY} && awk -F '[="]' '/^VERSION/{print $3}' ${V2FLY})"

MAGIC_URL="852us.com"
DOMAIN="852us.com"
FAKE_DOMAIN="https://www.gnu.org"
FLOW_PATH="/api"
PROTOCOL="vmess"
TRANSPORT="ws" # WebSocket
UUID=$(uuidgen -r)
LOCAL_PORT=$(shuf -i60000-65535 -n1)
PROXY_CONFIG_FILE="${V2RAY_CONFIG_PATH}/client.json"
LOCAL_IP=$(curl -s "https://ifconfig.me")

_exit() {
  echo
  exit $@
}

green() {
  echo -e "${GREEN}$@${NOCOLOR}"
}

red() {
  echo -e "${RED}$@${NOCOLOR}"
}

cyan() {
  echo -e "${CYAN}$@${NOCOLOR}"
}

error() {
  red "输入错误，请重新输入正确的内容 ..."
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

install_v2fly() {
  V2FLY_URL="https://raw.githubusercontent.com/852us/v2fly/main/install.sh?v=$RANDOM"
  echo
  echo "安装v2fly安装脚本 ..."
  curl -s ${V2FLY_URL} > ${V2FLY}
  chmod +x ${V2FLY}
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
      echo "Removed the file $f ..."
      rm -f $f
    fi
  done
}

rm_dirs() {
  for d in $@; do
    if [[ -d $d ]]; then
      echo "Removed the directory $f ..."
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

uninstall_v2fly() {
  rm_files ${V2FLY}
}

get_info_from_config() {
  if [[ ! -f ${CADDY_CONFIG_FILE} ]] || [[ ! -f ${V2RAY_CONFIG_FILE} ]]; then
    return
  fi
  CONFIG_PS=$(head -n 1 ${CADDY_CONFIG_FILE} | awk -F ' ' '{print $1}')
  CONFIG_ADD=${CONFIG_PS}
  CONFIG_HOST=${CONFIG_PS}
  CONFIG_FLOW_PATH="$(awk -F ' ' '/handle_path/{print $2}' ${CADDY_CONFIG_FILE})"
  CONFIG_FAKE_DOMAIN=$(awk -F ' ' '/reverse_proxy/{print $2}' ${CADDY_CONFIG_FILE} | head -n1)

  CONFIG_REMOTE_PORT="443"
  CONFIG_ID=$(sed 's/ //g' ${V2RAY_CONFIG_FILE} | awk -F '[:,"]' '/"id"/{print $5}')
  CONFIG_AID=$(sed 's/ //g' ${V2RAY_CONFIG_FILE} | awk -F '[:,"]' '/"alterId"/{print $4}')
  CONFIG_NET=$(sed 's/ //g' ${V2RAY_CONFIG_FILE} | awk -F '[:,"]' '/"network"/{print $5}')
  CONFIG_TLS=$(sed 's/ //g' ${V2RAY_CONFIG_FILE} | awk -F '[:,"]' '/"tls"/{print $2}')
  CONFIG_LOCAL_PORT=$(sed 's/ //g' ${V2RAY_CONFIG_FILE} | awk -F '[:,"]' '/"port"/{print $4}')
  CONFIG_PROTOCOL=$(sed 's/ //g' ${V2RAY_CONFIG_FILE} | awk -F '[:,"]' '/"protocol"/{print $5}' | head -n1)
}

write_proxy_config() {
  if [[ -f ${CADDY_CONFIG_FILE} ]] || [[ -f ${V2RAY_CONFIG_FILE} ]]; then
    get_info_from_config
  else
    CONFIG_PS=${DOMAIN}
    CONFIG_ADD=${CONFIG_PS}
    CONFIG_HOST=${CONFIG_PS}
    CONFIG_FLOW_PATH=${FLOW_PATH}
    CONFIG_REMOTE_PORT=443
    CONFIG_ID=${UUID}
    CONFIG_AID=0
    CONFIG_NET=${TRANSPORT}
    CONFIG_TLS="tls"
  fi

  if [ ${CONFIG_PROTOCOL} = "vmess" ] ; then
    cat >${PROXY_CONFIG_FILE} <<-EOF
{
  "v": "2",
  "ps": "${CONFIG_PS}",
  "add": "${CONFIG_ADD}",
  "port": "${CONFIG_REMOTE_PORT}",
  "id": "${CONFIG_ID}",
  "aid": "${CONFIG_AID}",
  "net": "${CONFIG_NET}",
  "type": "none",
  "host": "${CONFIG_HOST}",
  "path": "${CONFIG_FLOW_PATH}",
  "tls": "${CONFIG_TLS}"
}
EOF
  fi
}

show_info() {
  write_proxy_config
  if [ ${CONFIG_PROTOCOL} = "vmess" ] ; then
    PROXY_URL_TEXT="${CONFIG_PROTOCOL}://${CONFIG_NET}+${CONFIG_TLS}:${CONFIG_ID}-${CONFIG_AID}@${CONFIG_HOST}:${CONFIG_REMOTE_PORT}"
    PROXY_URL_TEXT="${PROXY_URL_TEXT}/?host=${CONFIG_HOST}&path=${CONFIG_FLOW_PATH}&tlsServerName=${CONFIG_ADD}#${CONFIG_PS}"
    PROXY_URL_BASE64="${CONFIG_PROTOCOL}://$(base64 -w 0 ${PROXY_CONFIG_FILE})"
  else
    PROXY_URL_TEXT="${CONFIG_PROTOCOL}://${CONFIG_ID}@${CONFIG_ADD}:${CONFIG_REMOTE_PORT}?encryption=none&security=${CONFIG_TLS}"
    PROXY_URL_TEXT="${PROXY_URL_TEXT}&type=${CONFIG_NET}&host=${CONFIG_HOST}&path=${CONFIG_FLOW_PATH}#${CONFIG_PS}"
    PROXY_URL_BASE64="${CONFIG_PROTOCOL}://$(base64 -w 0 ${PROXY_CONFIG_FILE})"
  fi
  echo
  echo "-------------------- 配置信息 --------------------"
  echo "协议: ${CONFIG_PROTOCOL}"
  echo "本地端口：${CONFIG_LOCAL_PORT}"
  echo "伪装域名：${CONFIG_FAKE_DOMAIN}"
  cat ${PROXY_CONFIG_FILE}
  echo
  echo "-------------------- V2Ray Proxy URL --------------------"
  if [ "${CONFIG_PROTOCOL}" = "vmess" ] ; then
    green ${PROXY_URL_BASE64}
    echo
    green ${PROXY_URL_TEXT}
  else
    green ${PROXY_URL_TEXT}
  fi
  echo
}

config_domain() {
  get_info_from_config
  while :; do
    echo
    red "请输入一个已经通过DNS解析到当前主机IP(${LOCAL_IP})的域名！"
    read -p "(例如：${MAGIC_URL}): " DOMAIN
    if [ -z "${DOMAIN}" ]; then
      red "输入的域名为空，重来 ..."
      continue
    fi

    echo
    green "输入的域名：${DOMAIN} "
    DOMAIN_IP=$(dig ${DOMAIN} | grep "^${DOMAIN}" | awk '{print $5}')
    if [[ "${DOMAIN_IP}" != "${LOCAL_IP}" ]]; then
      red "${DOMAIN}(${DOMAIN_IP})，本地IP(${LOCAL_IP})，输入的域名未正确解析到当前主机 ... "
      continue
    else
      green "${DOMAIN}(${DOMAIN_IP})，本地IP(${LOCAL_IP})，输入的域名已正确解析到当前主机 ... "
      CONFIG_PS=${DOMAIN}
      CONFIG_ADD=${CONFIG_PS}
      CONFIG_HOST=${CONFIG_PS}
      break
    fi
  done
}

config_protocol() {
  get_info_from_config
  while :; do
    echo
    red "选择协议："
    echo
    green " 1. vmess (默认选项)"
    echo
    green " 2. vless"
    echo

    read -p "$(echo 请选择[1-2]:)" choose
    case $choose in
    2)
      PROTOCOL="vless"
      break
      ;;
    1 | *)
      PROTOCOL="vmess"
      break
      ;;
    esac
  done
  CONFIG_PROTOCOL=${PROTOCOL}
}

config_local_port() {
  get_info_from_config
  while :; do
    echo
    red "请输入一个本地端口号："
    read -p "端口号要求(10000~65535之间): " LOCAL_PORT
    if [ -z "${LOCAL_PORT}" ]; then
      red "输入的端口号为空，重来 ..."
      continue
    elif [ ${LOCAL_PORT} -lt 10000 ] || [ ${LOCAL_PORT} -gt 65535 ]; then
      red "输入的端口号不在10000~65535之间，重来 ..."
      continue
    else
      echo
      green "输入了有效的端口号：${LOCAL_PORT} "
      CONFIG_LOCAL_PORT=${LOCAL_PORT}
      break
    fi
  done
}

config_id () {
  get_info_from_config
  green "ID从  ${CONFIG_ID}  更改为  ${UUID}"
  CONFIG_ID=${UUID}
}

config_fake_doamin () {
  get_info_from_config
  while :; do
    echo
    red "请输入新的伪装域名："
    read -p "必须是有效的域名(如：https://www.gnu.org): " FAKE_DOMAIN
    if [ -z "${FAKE_DOMAIN}" ]; then
      red "输入的伪装域名为空，重来 ..."
      continue
    fi

    [ -z $(echo ${FAKE_DOMAIN} | grep http) ] && FAKE_DOMAIN="https://${FAKE_DOMAIN}"
    FAKE_DOMAIN=$(echo ${FAKE_DOMAIN} | sed 's|/$||') # 去除末尾可能存在的'/'字符，保证Caddy正常运行
    if [ $(curl -s -o /dev/null -w %{http_code} ${FAKE_DOMAIN}) -ne 200 ]; then
      red "输入的端伪装域名无效，重来 ..."
      continue
    fi
    break
  done
  echo
  green "有效域名：${FAKE_DOMAIN} "
  CONFIG_FAKE_DOMAIN=${FAKE_DOMAIN}
}

config_flow_path () {
  get_info_from_config
  while :; do
    echo
    red "请输入新的分流路径："
    read -p "不用输入'/'字符(如：/api 输入 api ): " FLOW_PATH
    if [ -z "${FLOW_PATH}" ]; then
      red "输入的伪装域名为空，重来 ..."
      continue
    fi
    FLOW_PATH=$(echo ${FLOW_PATH} | sed 's|/*$||g' | sed 's|^/*||g')
    FLOW_PATH="/${FLOW_PATH}"
    break
  done
  echo
  green "有效的路径名：${FLOW_PATH} "
  CONFIG_FLOW_PATH=${FLOW_PATH}
}

write_caddy_config() {
  [[ ! -d ${CADDY_CONFIG_PATH}/sites ]] && mkdir -p ${CADDY_CONFIG_PATH}/sites

  [ -z ${CONFIG_HOST} ] && CONFIG_HOST=${DOMAIN}
  [ -z ${CONFIG_FAKE_DOMAIN} ] && CONFIG_FAKE_DOMAIN=${FAKE_DOMAIN}
  [ -z ${CONFIG_LOCAL_PORT} ] && CONFIG_LOCAL_PORT=${LOCAL_PORT}

  CONFIG_FLOW_PATH=${FLOW_PATH}

  cat >${CADDY_CONFIG_FILE} <<-EOF
${CONFIG_HOST} {
  reverse_proxy ${CONFIG_FAKE_DOMAIN} {
    header_up Host {upstream_hostport}
    header_up X-Forwarded-Host {host}
  }
  handle_path ${CONFIG_FLOW_PATH} {
    reverse_proxy 127.0.0.1:${CONFIG_LOCAL_PORT}
  }
}
import sites/*
EOF
  green "Caddy已正确配置 ... "
}

write_v2ray_config() {
  [[ ! -d ${V2RAY_CONFIG_PATH} ]] && mkdir -p ${V2RAY_CONFIG_PATH}

  [ -z ${CONFIG_LOCAL_PORT} ] && CONFIG_LOCAL_PORT=${LOCAL_PORT}
  [ -z ${CONFIG_ID} ] && CONFIG_ID=${UUID}
  [ -z ${CONFIG_NET} ] && CONFIG_NET="ws"
  [ -z ${CONFIG_PROTOCOL} ] && CONFIG_PROTOCOL=${PROTOCOL}

  cat >${V2RAY_CONFIG_FILE} <<-EOF
{
  "log": {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": ${CONFIG_LOCAL_PORT},
      "protocol": "${CONFIG_PROTOCOL}",
      "settings": {
        "clients": [
          {
            "id": "${CONFIG_ID}",
            "level": 1,
            "alterId": 0
          }
        ],
        "decryption": "none"
      },
      "listen": "127.0.0.1",
      "streamSettings": {
        "network": "${CONFIG_NET}"
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
  if [[ -d ${V2RAY_LOG_PATH} ]]; then
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
ExecStart=${V2RAY} run -config ${V2RAY_CONFIG_FILE}
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
  echo
  echo "检测V2Ray与Caddy服务的状态，需要等待2秒 ... "
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
  check_services_status
  echo
  echo -e "V2Ray 状态: $V2RAY_STATUS  /  Caddy 状态: $CADDY_STATUS ${NOCOLOR}"
  echo
}

start_services() {
  green "启动 V2Ray 与 Caddy 服务"
  systemctl start caddy v2ray
  show_service_status
}

stop_services() {
  echo
  red "停止Caddy与V2Ray服务"
  systemctl stop caddy v2ray
  show_service_status
}

restart_services() {
  stop_services
  start_services
}

prepare_system() {
  get_pkg_cmd
  update_os
  install_packages
  set_timezone
}

config() {
  if [[ ! -f ${CADDY_CONFIG_FILE} ]] || [[ ! -f ${V2RAY_CONFIG_FILE} ]]; then
    config_domain
    config_protocol
    write_caddy_config
    write_v2ray_config
    install_services
  fi
}

install() {
  get_SYS_BIT
  install_v2fly
  install_caddy
  install_v2ray
  config
  show_service_status
  show_info
}

uninstall() {
  uninstall_caddy
  uninstall_v2ray
  uninstall_v2fly
  show_service_status
}

reconfig() {
  write_caddy_config
  write_v2ray_config
  restart_services
  show_info
}

show_config_menu() {
  while :; do
    echo
    red "修改配置信息："
    echo
    green " 1. 修改域名"
    echo
    green " 2. 修改协议"
    echo
    green " 3. 修改端口"
    echo
    green " 4. 修改ID"
    echo
    green " 5. 修改伪装域名"
    echo
    green " 6. 修改分流路径"
    echo
    read -p "$(echo 请选择[1-6]:)" choose
    case $choose in
    1)
      config_domain
      break
      ;;
    2)
      config_protocol
      break
      ;;
    3)
      config_local_port
      break
      ;;
    4)
      config_id
      break
      ;;
    5)
      config_fake_doamin
      break
      ;;
    6)
      config_flow_path
      break
      ;;
    *)
      error
      ;;
    esac
  done
  reconfig
  echo
}

show_version () {
  echo "v2fly: ${V2FLY_VERSION}"
  echo
}
show_main_menu() {
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
    green " 6. 修改配置信息"
    echo
    read -p "$(echo 请选择[1-6]:)" choose
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
    6)
      show_config_menu
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

  $0 c | config: 配置V2Ray与Caddy

  $0 h | help: 显示本帮助信息

  $0 i | install: 安装 V2Ray与Caddy

  $0 I | install_all: 更新操作系统、安装必要模块、安装 V2Ray与Caddy

  $0 l | link: 显示客户端连接信息

  $0 m | menu: 管理 V2Ray (同等于直接输入 $0)

  $0 r | restart: 重启 V2Ray 与 Caddy 服务

  $0 s | start: 启动 Caddy 与 V2Ray 服务

  $0 S | stop: 停止 V2Ray 与 Caddy 服务

  $0 st | status: 显示 V2Ray 与 Caddy 服务的状态

  $0 u | uninstall: 卸载 V2Ray

  $0 v | version: 显示版本信息
"
}

main() {
  verify_root_user
  args=$1
  [ -z $1 ] && args="menu"
  case $args in
  c | config)
    show_config_menu
    ;;
  i | install)
    install
    ;;
  I | install_all)
    prepare_system
    install
    ;;
  l | link)
    show_info
    ;;
  m | menu)
    show_main_menu
    ;;
  r | restart)
    restart_services
    ;;
  s | start)
    start_services
    ;;
  S | stop)
    stop_services
    ;;
  st | status)
    show_service_status
    ;;
  u | uninstall)
    uninstall
    ;;
  v | version)
    show_version
    ;;
  h | help | *)
    show_help $0
    ;;
  esac
}

main $@
