# XFCE 桌面 —— 主机配置一行导入：(self + /modules/nixos/desktop/xfce.nix)
{ flake, ... }:

{
  # 桌面需要用户态 GUI 模块
  home-manager.sharedModules = [ flake.inputs.self.homeModules.gui ];

  services.xserver = {
    enable = true;
    desktopManager = {
      xterm.enable = false;
      xfce.enable = true;
    };
  };
  services.displayManager.defaultSession = "xfce";
}
