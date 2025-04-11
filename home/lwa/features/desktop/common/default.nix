{ pkgs, ... }:

{
  imports = [
    ./vscode.nix
    ./firefox
  ];

  home.packages = with pkgs; [
    vlc
    qcm
    scrcpy
    fsearch
    xunlei-uos
    wechat-uos
    dev-sidecar
    wpsoffice-cn
    qbittorrent-enhanced
    netease-cloud-music-gtk
  ];
}
