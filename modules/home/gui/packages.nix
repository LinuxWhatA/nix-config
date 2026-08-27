{ pkgs, ... }:

{
  home.packages = with pkgs; [
    vlc
    scrcpy
    wechat
    fsearch
    xunlei-uos
    motrix-next
    moonlight-qt
    wpsoffice-cn
    winetricks
    wineWow64Packages.staging
  ];
}
