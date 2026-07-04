{
  # Enable the COSMIC login manager
  services.displayManager.cosmic-greeter.enable = true;
  # Enable the COSMIC desktop environment
  services.desktopManager.cosmic.enable = true;
  # 允许全局访问剪贴板（不安全）
  environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = 1;
}
