# XFCE 桌面 —— 主机配置一行导入：(self + /modules/nixos/desktop/xfce.nix)
{
  # 桌面需要用户态 GUI 模块（经 desktop-host.nix 注入到桌面用户，root 不继承）

  services.xserver = {
    enable = true;
    desktopManager = {
      xterm.enable = false;
      xfce.enable = true;
    };
  };
  services.displayManager.defaultSession = "xfce";
}
