{ pkgs, ... }:

{
  imports = [
    ./zsh
    ./git.nix
    ./direnv.nix
  ];

  home.packages = with pkgs; [
    fhs
    rar
    yazi
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
