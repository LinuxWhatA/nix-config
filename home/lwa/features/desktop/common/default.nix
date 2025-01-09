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
    wechat-uos
    wpsoffice-cn
    lx-music-desktop
    qbittorrent-enhanced
  ];
}
