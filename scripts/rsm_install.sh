#!/usr/bin/env bash


APP_URL=https://www.debuggerx.com/raw_assets/bin/rsm_server

HOME_DIR=$HOME
EXE_DIR=$HOME_DIR/.local/share/remote_system_monitor
EXE_FILE=$EXE_DIR/server
AUTOSTART_DIR=$HOME_DIR/.config/autostart
AUTOSTART_FILE=$AUTOSTART_DIR/rsm_server.desktop
SERVICE_FILE=/usr/lib/systemd/system/rsm_server.service

function download() {
  ARCH=$(uname -m)
  if [[ $ARCH == "x86_64" ]]; then
    ARCH="x64"
  elif [[ $ARCH == "aarch64" ]]; then
    ARCH="arm64"
  else
    echo "不支持的CPU架构：[$ARCH]"
    exit 1
  fi
  echo "开始下载服务端程序"
  wget "$APP_URL"_"$ARCH" -O "$EXE_FILE"
  sudo chmod a+x $EXE_FILE
  VERSION=$($EXE_FILE -v)
  if [[ $VERSION -gt 0 ]]; then
    echo "下载完成，服务端程序版本[$VERSION]"
  else
    echo "下载服务端程序出错，请重试"
    exit 1
  fi
}


if [ "$(whoami)" == "root" ]
then
  echo '请不要直接以root权限执行本安装脚本！！！'
  exit 1
else
  echo "本安装脚本在安装过程中需要root权限来安装必须的组件和服务"
  echo "请根据提示输入密码后回车继续"
fi

echo '-----------------------------------------------------'

mkdir -p $AUTOSTART_DIR

declare -A INSTALL_CMDS;
INSTALL_CMDS[/etc/redhat-release]="yum install"
INSTALL_CMDS[/etc/arch-release]="pacman -S"
INSTALL_CMDS[/etc/gentoo-release]="emerge"
INSTALL_CMDS[/etc/SuSE-release]="zypp install"
INSTALL_CMDS[/etc/debian_version]="apt-get install"
INSTALL_CMDS[/etc/alpine-release]="apk add"

INSTALL_CMD=""

for f in "${!INSTALL_CMDS[@]}"
do
    if [[ -f $f ]];then
        INSTALL_CMD="${INSTALL_CMDS[$f]}"
    fi
done

if [[ $INSTALL_CMD == "" ]]; then
    echo "不支持的系统"
    exit 1
fi

if [[ $(systemctl is-active avahi-daemon.service) == "active" ]]; then
  echo "avahi服务已正确安装"
else
  echo "尝试安装avahi-daemon"
  # shellcheck disable=SC2086
  sudo $INSTALL_CMD avahi-daemon
fi

if which wget >/dev/null ; then
  echo "wget工具已正确安装"
else
  echo "尝试安装wget"
  # shellcheck disable=SC2086
  sudo $INSTALL_CMD wget
fi

if [[ -e $EXE_DIR ]]; then
  echo "程序目录已存在"
else
  mkdir "$EXE_DIR"
fi

if [[ -f $EXE_FILE ]]; then
  sudo chmod a+x $EXE_FILE
  VERSION=$($EXE_FILE -v)
  if [[ $VERSION -gt 0 ]]; then
    echo "服务端程序已存在，版本[$VERSION]"
  else
    sudo rm $EXE_FILE
    download
  fi
else
  download
fi

echo "请输入服务端监听的端口号[1024~65535]，或者直接回车使用默认端口:"
read -rp "[1024~65535]" PORT

if [[ $PORT == '' ]]; then
  PORT=9999
fi

if [[ $PORT -gt 65535 ]]; then
  echo "服务端监听的端口不能超过65535！！！"
  exit 1
fi

if [[ $PORT -lt 1024 ]]; then
  echo "服务端监听的端口不能小于1024！！！"
  exit 1
fi

echo "请选择服务运行模式："
echo "1. 桌面模式 - 服务将会在登录桌面后以当前用户身份自动启动"
echo "2. 服务器模式 - 服务将会在系统启动后以root身份自动启动"
echo "请根据您的实际情况，输入1或2后回车"
read -rp "[1/2]" MODE

if [[ $MODE -eq 1 ]]; then
  echo "服务将以桌面模式安装"
  cat > $AUTOSTART_FILE << EOF
[Desktop Entry]
Version=1.0
Encoding=UTF-8
Name=rsm_server
Comment=remote system monitor server
Exec=$EXE_FILE -p $PORT
Terminal=false
Type=Application
Categories=
GenericName=
EOF

  chmod a+x $AUTOSTART_FILE

  echo "服务端程序已正确配置！今后将在每次进入桌面时自动运行~"
elif [[ $MODE -eq 2 ]]; then
  echo "服务将以服务器模式安装"
  cat > /tmp/rsm_server.service << EOF
[Unit]
Description=server of remote system monitor
Wants=network-online.target
After=network.target

[Service]
ExecStart=$EXE_FILE -p $PORT

[Install]
WantedBy=multi-user.target

EOF

sudo mv /tmp/rsm_server.service $SERVICE_FILE
sudo systemctl daemon-reload
sudo systemctl enable rsm_server.service

  echo "服务端程序已正确配置！今后将在每次开机时自动运行~"
else
  echo "模式选在错误，退出安装！！！"
  exit 1
fi


echo "您可以扫描下方二维码下载安卓端APP:"

$EXE_FILE -a

$EXE_FILE -p $PORT

