#!/bin/bash

# 简化版 UU 加速器监控脚本

# 基本配置
RUNNING_DIR="/tmp/uu"
INSTALL_DIR="$RUNNING_DIR/usr/lib/uu"
CONFIG_DIR="$RUNNING_DIR/etc/uu"
PLUGIN_TAR="uu.tar.gz"
PLUGIN_EXE="uuplugin"
PLUGIN_CONF="uu.conf"
# 由本脚本自行写入/校验；放 RUNNING_DIR 而非 /run，免去写权限问题与跨启动残留
PID_FILE="$RUNNING_DIR/uuplugin.pid"
PLUGIN_TAR_MD5_FILE="uu.tar.gz.md5"
DOWNLOAD_URL="https://router.uu.163.com/api/plugin?type=steam-deck-plugin-x86_64"

# 确保目录存在
mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "$RUNNING_DIR"
cd "$RUNNING_DIR"

# 下载插件包
download_plugin() {
    local tmp_file="$RUNNING_DIR/$PLUGIN_TAR"
    local plugin_info=$(curl -s -k -H "Accept:text/plain" "$DOWNLOAD_URL")

    [ -z "$plugin_info" ] && return 1

    local plugin_url=$(echo "$plugin_info" | cut -d',' -f1)
    local plugin_md5=$(echo "$plugin_info" | cut -d',' -f2)

    if ! curl -s -k "$plugin_url" -o "$tmp_file"; then
        rm -f "$tmp_file"
        return 1
    fi

    local download_md5=$(md5sum "$tmp_file" | awk '{print $1}')
    if [ "$download_md5" != "$plugin_md5" ]; then
        rm -f "$tmp_file"
        return 1
    fi

    # 解压并安装
    if tar -xzf "$tmp_file" -C "$RUNNING_DIR"; then
        chmod +x "$RUNNING_DIR/$PLUGIN_EXE"
        mv "$tmp_file" "$INSTALL_DIR/"
        echo "$plugin_md5" > "$INSTALL_DIR/$PLUGIN_TAR_MD5_FILE"
        return 0
    fi

    rm -f "$tmp_file"
    return 1
}

# 检查是否运行（按 pid 且确为 uuplugin 进程，防 PID 复用误判）
is_running() {
    [ -f "$PID_FILE" ] || return 1
    local pid
    read -r pid < "$PID_FILE" || return 1
    [ -n "$pid" ] || return 1
    grep -q uuplugin "/proc/$pid/cmdline" 2>/dev/null
}

# 启动插件（成功后回写自身 pid，避免每轮循环重复拉起）
start_plugin() {
    if is_running; then
        return 0
    fi
    if [ -f "$RUNNING_DIR/$PLUGIN_EXE" ]; then
        "$RUNNING_DIR/$PLUGIN_EXE" "$CONFIG_DIR/$PLUGIN_CONF" >/dev/null 2>&1 &
        echo $! > "$PID_FILE"
        return 0
    elif [ -f "$INSTALL_DIR/$PLUGIN_TAR" ]; then
        if tar -xzf "$INSTALL_DIR/$PLUGIN_TAR" -C "$RUNNING_DIR"; then
            chmod +x "$RUNNING_DIR/$PLUGIN_EXE"
            "$RUNNING_DIR/$PLUGIN_EXE" "$CONFIG_DIR/$PLUGIN_CONF" >/dev/null 2>&1 &
            echo $! > "$PID_FILE"
            return 0
        fi
    fi
    return 1
}

# 主循环
while true; do
    if ! is_running; then
        if ! start_plugin; then
            if ! download_plugin; then
                echo "无法下载或启动插件，将在5秒后重试..."
                sleep 5
                continue
            fi
            start_plugin
        fi
    fi
    sleep 60
done
