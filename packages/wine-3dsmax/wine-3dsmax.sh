#!/usr/bin/env bash
set -euo pipefail

: "${MAX_REPO:?请通过 wine-3dsmax 包装入口运行}"

usage() {
  cat <<'EOF'
用法: wine-3dsmax [子命令] [参数…]

  run [file.max…]                  启动 3ds Max 2027（默认子命令）
  setup-runtimes                   离线装随包的 DXVK 与 wine-mono（新建 prefix 用）
  setup-prefix                     建 prefix，装 VC++/.NET 8/10/WebView2 + 随包运行时
  install-licensing                装 Autodesk Desktop Licensing
  install-max-msi                  装 3dsMax.msi
  install-identity-manager         装 ODIS + Identity Manager 与 adskidmgr:// 回调
  set-named-user                   设为 Autodesk 账号授权
  setup-webview2                   WebView2 参数与 DLL 覆盖
  set-privacy-consent [0|1] [0|1]  记录隐私选项，避开首次启动对话框
  install-launcher                 生成桌面图标与 .max 文件关联
  install-url-handler              单独注册 URL 回调
  adsk-url-handler <url>           浏览器回调转发（通常由桌面 handler 调用）
  --help                           显示本帮助

  安装介质目录由 MAXSRC 指定（默认 ~/3dsmax-setup），prefix 由 WINEPREFIX 指定
  （默认 ~/.wine-3dsmax）；补丁版 Wine 已由 Nix 构建，无需 build-wine.sh 等步骤；
  DXVK 与 wine-mono 随包自带，新建 prefix 时执行 setup-runtimes 即可离线装配。
  首次安装按 setup-prefix → install-licensing → install-max-msi →
  install-identity-manager → set-named-user → setup-webview2 → install-launcher 顺序执行。
  补丁 Wine 也可单独用：wine-3dsmax-wine，同目录还有 wine-3dsmax-winepath、
  wine-3dsmax-wineserver 等配套工具；默认 WINEPREFIX 为 ~/.wine-3dsmax，可由外部覆盖。
EOF
}

stages=(
  setup-runtimes setup-prefix install-licensing install-max-msi install-identity-manager
  set-named-user setup-webview2 set-privacy-consent install-launcher
  install-url-handler adsk-url-handler
)

case "${1:-run}" in
  -h | --help)
    usage
    exit 0
    ;;
  run)
    [[ $# -eq 0 ]] || shift
    ;;
  *)
    for stage in "${stages[@]}"; do
      if [[ "$1" == "$stage" ]]; then
        shift
        exec "$MAX_REPO/scripts/$stage.sh" "$@"
      fi
    done
    echo "未知子命令: $1" >&2
    usage >&2
    exit 2
    ;;
esac

prefix="${WINEPREFIX:-$HOME/.wine-3dsmax}"
exe="$prefix/drive_c/Program Files/Autodesk/3ds Max 2027/3dsmax.exe"
if [[ ! -f "$exe" ]]; then
  echo "未找到 $exe" >&2
  echo "请先按 wine-3dsmax --help 里的顺序完成安装" >&2
  exit 1
fi
exec "$MAX_REPO/scripts/run-3dsmax.sh" "$@"
