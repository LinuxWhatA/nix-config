{ flake, pkgs, ... }:

{
  home-manager.users.${flake.config.me.username}.home = {
    packages = [ pkgs.dev-sidecar ];
    file = {
      ".dev-sidecar/dev-sidecar.ca.crt" = {
        force = true;
        source = "${pkgs.dev-sidecar}/dev-sidecar.ca.crt";
      };
      ".dev-sidecar/dev-sidecar.ca.key.pem" = {
        force = true;
        source = "${pkgs.dev-sidecar}/dev-sidecar.ca.key.pem";
      };
    };
    activation.DevSidecarSettings =
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
  };

  security.pki.certificateFiles = [
    "${pkgs.dev-sidecar}/dev-sidecar.ca.crt"
  ];
}
