{ pkgs, ... }:

{
  home.packages = with pkgs; [
    vlc
    scrcpy
    wechat
    flclash
    fsearch
    xunlei-uos
    motrix-next
    moonlight-qt
    wpsoffice-cn
    qbittorrent-enhanced
  ];
}
