{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Unix tools
    ripgrep # Better `grep`
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
    nix-info
    nixfmt-rfc-style

    # Custom Program
    fhs
    proton-run
    patchedpython
    winePackages.stagingFull
    winetricks
    vlc
    scrcpy
    wechat
    fsearch
    xunlei-uos
    moonlight-qt
    wpsoffice-cn
    qbittorrent-enhanced
  ];

  programs = {
    nix-index = {
      enable = true;
      enableZshIntegration = true;
    };
    nix-index-database.comma.enable = true;
    fzf.enable = true;
    jq.enable = true;
    htop.enable = true;
    btop.enable = true;
  };
}
