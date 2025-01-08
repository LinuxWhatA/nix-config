{ pkgs, ... }:

{
  imports = [
    ./vscode.nix
    ./firefox
  ];

  home.packages = with pkgs; [
    vlc
    xunlei
    fsearch
    xarchiver
    wechat-uos
    wpsoffice-cn
    lx-music-desktop
    qbittorrent-enhanced
  ];
}
