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
    nh
    nixd
    nixfmt
    nix-info

    # Custom Program
    fhs
    cdrtools
    proton-run
    patchedpython
    winePackages.stagingFull
    winetricks
  ];

  programs = {
    nix-index = {
      enable = true;
      enableZshIntegration = true;
    };
    # nix-index-database.comma.enable = true;
    fzf.enable = true;
    jq.enable = true;
    htop.enable = true;
  };
}
