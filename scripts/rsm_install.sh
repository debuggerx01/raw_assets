#!/usr/bin/env bash


APP_URL=https://www.debuggerx.com/raw_assets/bin/rsm_server_x64

HOME_DIR=$HOME
EXE_DIR=$HOME_DIR/.local/share/remote_system_monitor
EXE_FILE=$EXE_DIR/server
AUTOSTART_FILE=$HOME_DIR/.config/autostart/rsm_server.desktop

function download() {
  echo "开始下载服务端程序"
  wget $APP_URL -O "$EXE_FILE"
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

read -rp "请输入服务端监听的端口号[1024~65535]，或者直接回车使用默认端口:" PORT

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

echo "您可以扫描下方二维码下载安卓端APP:"

$EXE_FILE -a

$EXE_FILE -p $PORT

