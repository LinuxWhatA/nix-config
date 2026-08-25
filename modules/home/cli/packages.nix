# 跨平台 CLI 工具
{ flake, pkgs, ... }:

{
  imports = [
    flake.inputs.nix-index-database.homeModules.nix-index
  ];

  home.packages = with pkgs; [
    # Unix tools
    sd
    gnumake
    less
    rar
    usbutils
    fastfetch
    pciutils
    vulkan-tools

    # Nix dev
    nixd
    nixfmt
    nix-info
    nix-alien

    # Custom Program
    fhs
    cdrtools
    python3
    proton-run
    dwproton-run
    umu-launcher
  ];

  programs = {
    nix-index-database.comma.enable = true;
    fzf.enable = true;
    jq.enable = true;
    htop.enable = true;
  };
}
