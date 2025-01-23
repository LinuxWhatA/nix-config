{ pkgs, ... }:

{
  imports = [
    ./vscode.nix
    ./firefox
  ];

  home.packages = with pkgs; [
    vlc
    qcm
    fsearch
    xunlei-uos
    wechat-uos
    dev-sidecar
    wpsoffice-cn
    qbittorrent-enhanced
    unblock-netease-music
  ];
}
