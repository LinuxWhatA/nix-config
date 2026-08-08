{ flake, pkgs, ... }:

{
  imports = [
    flake.inputs.nix-index-database.nixosModules.default
  ];
  environment.systemPackages = with pkgs; [
    file
    tree
    lsof
    wget
    net-tools
    android-tools
  ];

  programs = {
    appimage.enable = true;
    appimage.binfmt = true;
    zoxide.enable = true;
    nix-index-database.enable = true;
  };

  users.users.${flake.config.me.username}.extraGroups = [ "adbusers" ];

  # 允许 Electron 在 Wayland 原生上运行
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };
}
