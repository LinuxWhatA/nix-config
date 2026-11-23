{
  lib,
  config,
  ...
}:
{
  # 会话启动脚本默认本仓主用的 plasma6 X11；不另设 option——nixpkgs 的
  # services.xrdp.defaultWindowManager 已可被使用方主机以正常优先级覆盖，
  # 这里用 mkDefault 仅替换默认值（xterm → plasma），通用服务不写死桌面。
  config.services.xrdp = {
    enable = true;
    openFirewall = true;
    defaultWindowManager = lib.mkDefault ''
      unset DBUS_SESSION_BUS_ADDRESS
      unset XDG_RUNTIME_DIR
      startplasma-x11
    '';
  };

  # 普通用户电源权限（XRDP，仅限 wheel）
  config.security.polkit = {
    enable = true;
    extraConfig = ''
      polkit.addRule(function (action, subject) {
        if (
          subject.isInGroup("wheel") &&
          [
            "org.freedesktop.login1.reboot",
            "org.freedesktop.login1.reboot-multiple-sessions",
            "org.freedesktop.login1.power-off",
            "org.freedesktop.login1.power-off-multiple-sessions",
          ].indexOf(action.id) !== -1
        ) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
