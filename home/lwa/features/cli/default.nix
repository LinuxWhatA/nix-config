{ pkgs, ... }:

{
  imports = [
    ./zsh

    ./direnv.nix
    ./git.nix
  ];

  home.packages = with pkgs; [
    fhs
    rar
    nixd
    htop
    usbutils
    fastfetch
    proton-run
    vulkan-tools
    patchedpython
    nixfmt-rfc-style

    (wineWowPackages.full.override {
      wineRelease = "staging";
      mingwSupport = true;
    })
    winetricks
  ];

  my.services.unblock-netease-music = {
    enable = true;
    env = "SEARCH_ALBUM=true";
  };
}
