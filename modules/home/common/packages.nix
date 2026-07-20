{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Unix tools
    fd
    sd
    gnumake
    less
    rar
    usbutils
    fastfetch
    vulkan-tools

    # Nix dev
    nixd
    nixfmt
    nix-info
    nix-alien

    # Custom Program
    fhs
    cdrtools
    patchedpython
    proton-run
    umu-launcher
    winetricks
    winePackages.stagingFull
  ];

  programs = {
    nix-index-database.comma.enable = true;
    fzf.enable = true;
    jq.enable = true;
    htop.enable = true;
  };
}
