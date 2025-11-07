{ flake, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    file
    tree
    lsof
    wget
    net-tools
  ];

  programs = {
    zsh.enable = true;
    adb.enable = true;
    appimage.enable = true;
    appimage.binfmt = true;
  };

  users.users.${flake.config.me.username}.extraGroups = [ "adbusers" ];

  # 允许 Electron 在 Wayland 原生上运行
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };
}
