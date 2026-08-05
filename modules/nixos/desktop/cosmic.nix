# COSMIC 桌面 —— 主机配置一行导入：(self + /modules/nixos/desktop/cosmic.nix)
{ flake, ... }:

{
  # 桌面需要用户态 GUI 模块
  home-manager.sharedModules = [ flake.inputs.self.homeModules.gui ];

  # 启用 COSMIC 登录管理器
  services.displayManager.cosmic-greeter.enable = true;
  # 启用 COSMIC 桌面环境
  services.desktopManager.cosmic.enable = true;
  # 允许全局访问剪贴板（不安全）
  environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = 1;
  services.system76-scheduler.enable = true;
}
