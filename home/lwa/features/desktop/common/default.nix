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
    dev-sidecar
    wpsoffice-cn
    lx-music-desktop
    qbittorrent-enhanced
  ];
}
