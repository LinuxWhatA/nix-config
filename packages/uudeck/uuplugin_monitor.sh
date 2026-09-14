#!/bin/bash
# 网易 UU 加速器 Steam Deck 插件（steam-deck-plugin）的守护脚本。
#
# 官方安装脚本会改宿主机：把 uuplugin.service 写进 /etc/systemd/system 并 enable、把自己装到 $HOME/uu、
# chmod 家目录、还把云端下发的 uninstall.sh 以 root 执行。本脚本反过来把落盘全收在 /tmp/uu，
# 不建服务、不碰家目录与 /etc、不执行下载来的脚本，退出时按进程组清掉自己拉起的全部进程。
# 唯一落在 /tmp/uu 之外的是 uuplugin 自己写的单实例锁 /var/run/uuplugin.pid：写不了它会立即退出
# （实测 exit 255），所以本脚本需要以 root 运行。

set -euo pipefail

RUNNING_DIR=/tmp/uu
PLUGIN_API='https://router.uu.163.com/api/plugin?type=steam-deck-plugin-x86_64'
PLUGIN_EXE=uuplugin
PLUGIN_CONF=uu.conf
PLUGIN_TAR=uu.tar.gz
PID_FILE=/var/run/uuplugin.pid

mkdir -p "$RUNNING_DIR"
cd "$RUNNING_DIR"

# 单实例：第二个 monitor 只会不断去撞插件自己的单实例锁，空转刷日志
exec 9>"$RUNNING_DIR/monitor.lock"
flock -n 9 || {
  echo "uudeck 已在运行" >&2
  exit 1
}

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >&2; }

[ -w "${PID_FILE%/*}" ] ||
  log "警告：${PID_FILE%/*} 不可写，uuplugin 无法建单实例锁，会立刻退出；请以 root 运行（sudo uudeck）"

# 接口返回 "<url>,<md5>,..."：url 是带签名的临时地址，md5 由服务端给出，用来挡住半截下载
download_plugin() {
  local info url md5
  info=$(curl -fsS --retry 3 --connect-timeout 3 -H 'Accept:text/plain' "$PLUGIN_API") || return 1
  url=$(cut -d, -f1 <<<"$info")
  md5=$(cut -d, -f2 <<<"$info")
  [ -n "$url" ] && [ -n "$md5" ] || return 1
  curl -fsS --retry 3 --connect-timeout 3 "$url" -o "$PLUGIN_TAR" || return 1
  if [ "$(md5sum "$PLUGIN_TAR" | cut -d' ' -f1)" != "$md5" ]; then
    rm -f "$PLUGIN_TAR"
    return 1
  fi
  tar xzf "$PLUGIN_TAR"
}

# 留下 uu.tar.gz 当离线缓存：包里是 uuplugin + xuplugin-guardian + uu.conf
ensure_plugin() {
  if [ -x "$PLUGIN_EXE" ] && [ -f "$PLUGIN_CONF" ]; then
    return 0
  fi
  if [ -f "$PLUGIN_TAR" ] && tar xzf "$PLUGIN_TAR" && [ -x "$PLUGIN_EXE" ]; then
    return 0
  fi
  download_plugin
}

plugin_pid=
# setsid 另起进程组：uuplugin 会把 xuplugin-guardian fork 出去并转交 init，按名字或按父子关系都收不回来
start_plugin() {
  setsid "$RUNNING_DIR/$PLUGIN_EXE" "$RUNNING_DIR/$PLUGIN_CONF" >>"$RUNNING_DIR/plugin.log" 2>&1 &
  plugin_pid=$!
  log "启动 uuplugin（pgid $plugin_pid）"
}

stop_plugin() {
  [ -n "$plugin_pid" ] || return 0
  kill -TERM -"$plugin_pid" 2>/dev/null || return 0
  for _ in 1 2 3 4 5; do
    kill -0 -"$plugin_pid" 2>/dev/null || return 0
    sleep 1
  done
  kill -KILL -"$plugin_pid" 2>/dev/null || true
}

cleanup() {
  stop_plugin
  log "退出"
}
trap cleanup EXIT
trap 'exit 1' INT TERM HUP

ensure_plugin || {
  log "插件包下载或校验失败"
  exit 1
}
start_plugin

while :; do
  # sleep 丢到后台再 wait：收到 TERM/INT 时 wait 立即返回，收尾不用等这一轮睡满
  sleep 10 &
  wait $! || true
  if kill -0 "$plugin_pid" 2>/dev/null; then
    continue
  fi
  log "uuplugin 已退出（日志 $RUNNING_DIR/plugin.log），重新拉起"
  stop_plugin
  ensure_plugin || {
    log "插件包下载或校验失败，稍后重试"
    continue
  }
  start_plugin
done
