#!/usr/bin/env bash
# 用包内资源离线装配 prefix：DXVK 走 Vulkan，避开 wined3d 的 GL 路径（长方体不可见）。
# wine-mono 一并装好，新 prefix 不必再联网下载。
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/env.sh"

[ -f "$WINEPREFIX/system.reg" ] || wineboot -i
winetricks -q win10

for dll in d3d8 d3d9 d3d10core d3d11 dxgi; do
  for arch in x64 x86; do
    src="$REPO/dxvk/$arch/$dll.dll"
    [ -f "$src" ] || { echo "缺 $src" >&2; exit 1; }
    if [ "$arch" = x64 ]; then
      dst="$WINEPREFIX/drive_c/windows/system32"
    else
      dst="$WINEPREFIX/drive_c/windows/syswow64"
    fi
    install -m644 "$src" "$dst/$dll.dll"
  done
  wine reg add 'HKCU\Software\Wine\DllOverrides' /v "$dll" /t REG_SZ /d native /f >/dev/null
done

mono="$REPO/wine-mono-11.3.0-x86.msi"
[ -f "$mono" ] || { echo "缺 $mono" >&2; exit 1; }
if [ ! -d "$WINEPREFIX/drive_c/windows/mono/mono-2.0" ]; then
  wine msiexec /i "$(winepath -w "$mono")" /q
fi
wineserver -w
echo "DXVK 与 wine-mono 已装到 $WINEPREFIX"
