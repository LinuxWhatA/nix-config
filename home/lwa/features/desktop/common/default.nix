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

  home.file = {
    ".dev-sidecar/dev-sidecar.ca.crt" = {
      force = true;
      source = "${pkgs.dev-sidecar}/dev-sidecar.ca.crt";
    };
    ".dev-sidecar/dev-sidecar.ca.key.pem" = {
      force = true;
      source = "${pkgs.dev-sidecar}/dev-sidecar.ca.key.pem";
    };
  };
}
