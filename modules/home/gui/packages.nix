{ pkgs, ... }:

{
  home.packages = with pkgs; [
    vlc
    scrcpy
    wechat
    flclash
    fsearch
    xunlei-uos
    moonlight-qt
    wpsoffice-cn
    qbittorrent-enhanced
  ];
}
