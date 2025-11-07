{
  services.xrdp = {
    enable = true;
    openFirewall = true;
    defaultWindowManager = ''
      unset DBUS_SESSION_BUS_ADDRESS
      unset XDG_RUNTIME_DIR
      startplasma-x11
    '';
  };

  # 普通用户电源权限（XRDP）
  security.polkit = {
    enable = true;
    extraConfig = ''
      polkit.addRule(function (action, subject) {
        if (
          subject.isInGroup("users") &&
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
