{ pkgs, ... }:

{
  home.packages = with pkgs; [
    vlc
    scrcpy
    wechat
    fsearch
    xunlei-uos
    moonlight-qt
    wpsoffice-cn
    qbittorrent-enhanced
  ];
}
