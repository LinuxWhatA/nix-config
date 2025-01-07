{ pkgs, ... }:

{
  imports = [
    ./vscode.nix
    ./firefox
  ];

  home.packages = with pkgs; [
    xunlei
    fsearch
    xarchiver
    wechat-uos
    wpsoffice-cn
    lx-music-desktop
    qbittorrent-enhanced
  ];
}
