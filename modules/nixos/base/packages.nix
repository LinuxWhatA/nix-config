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
    psmisc
    net-tools
    android-tools
    ntfs3g
  ];

  programs = {
    appimage.enable = true;
    appimage.binfmt = true;
    zoxide.enable = true;
    nix-index-database.enable = true;
  };

  # 允许 Electron 在 Wayland 原生上运行
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };
}
