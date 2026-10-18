{ pkgs, ... }:

{
  home.packages = with pkgs; [
    vlc
    scrcpy
    wechat
    fsearch
    rayburst
    xunlei-uos
    moonlight-qt
    wpsoffice-cn
    winetricks
    deepin-wine10-stable
    wineWow64Packages.staging
    proton-run
    dwproton-run
    umu-launcher
    dsh-desktop-next
  ];
}
