# COSMIC 桌面 —— 主机配置一行导入：(self + /modules/nixos/desktop/cosmic.nix)
{
  # 桌面需要用户态 GUI 模块（经 desktop-host.nix 注入到桌面用户，root 不继承）

  services = {
    # 启用 COSMIC 登录管理器
    displayManager.cosmic-greeter.enable = true;
    # 启用 COSMIC 桌面环境
    desktopManager.cosmic.enable = true;
    system76-scheduler.enable = true;
  };
  # 允许全局访问剪贴板（不安全）
  environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = 1;
}
