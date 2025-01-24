{ pkgs, ... }:

{
  imports = [
    ./git.nix
  ];

  home.packages = with pkgs; [
    fhs
    rar
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

  my.services.unblock-netease-music.enable = true;
}
