# WSLg tray bridge — Linux 侧
#
# microsoft/wslg#158: 在 WSL2/WSLg 里把 Linux 托盘图标（StatusNotifierItem）
# 桥接到 Windows 任务栏。本包只含 WSL/Linux 侧服务 sni-host；
# Windows 侧的 tray_host.py 是独立项目（wslg-tray-bridge）。
#
# 用法：
#   nix run .#sni-host            # 或系统安装后直接 sni-host
#   sni-host --no-spawn           # 不自动拉起 Windows 侧
#
{
  lib,
  python3,
  writeScriptBin,
}:
let
  src = lib.cleanSource ./src;
  pyEnv = python3.withPackages (ps: [
    ps.dbus-next # D-Bus (GLib-free)
    ps.pillow # IconPixmap ARGB32 → PNG
  ]);
in
writeScriptBin "sni-host" ''
  exec ${pyEnv}/bin/python3 ${src}/sni_host.py "$@"
''
// {
  meta = {
    description = "Bridge Linux StatusNotifierItem tray icons to the Windows taskbar (WSLg side)";
    homepage = "https://github.com/microsoft/wslg/issues/158";
    license = lib.licenses.mit;
    mainProgram = "sni-host";
    platforms = lib.platforms.linux;
  };
}
