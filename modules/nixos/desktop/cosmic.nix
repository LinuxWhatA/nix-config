{ flake, pkgs, ... }:

{
  services = {
    # 启用 COSMIC 登录管理器
    displayManager.cosmic-greeter.enable = true;
    # 启用 COSMIC 桌面环境
    desktopManager.cosmic.enable = true;
    system76-scheduler.enable = true;
    displayManager.autoLogin = {
      enable = true;
      user = "${flake.config.me.username}";
    };
  };

  environment.systemPackages = [
    pkgs.cosmic-ext-applet-minimon
  ];

  # 允许全局访问剪贴板（不安全）
  environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = 1;
}
