{ pkgs, ... }:

{
  imports = [
    ./vscode.nix
    ./firefox
  ];

  home.packages = with pkgs; [
    vlc
    fsearch
    xunlei-uos
    wechat-uos
    wpsoffice-cn
    lx-music-desktop
    qbittorrent-enhanced
  ];
}
