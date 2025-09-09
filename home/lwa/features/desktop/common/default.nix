{ pkgs, ... }:

{
  imports = [
    ./vscode.nix
    ./firefox
  ];

  home.packages = with pkgs; [
    vlc
    qcm
    wechat
    scrcpy
    fsearch
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

  home.activation.DevSidecarSettings =
    let
      setting = builtins.toJSON {
        overwall = true;
      };
    in
    ''
      file="$HOME/.dev-sidecar/setting.json"
      [ -f $file ] || (mkdir -p $(dirname $file) && echo "{}" > $file)
      json=$(${pkgs.fixjson}/bin/fixjson --minify $file)
      echo $json '${setting}' | ${pkgs.jq}/bin/jq -s add > $file
    '';
}
