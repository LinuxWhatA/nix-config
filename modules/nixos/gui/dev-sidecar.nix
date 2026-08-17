{ flake, pkgs, ... }:

let
  inherit (pkgs) dev-sidecar;
in
{
  home-manager.users.${flake.config.me.username}.home = {
    packages = [ dev-sidecar ];
    file = {
      ".dev-sidecar/dev-sidecar.ca.crt" = {
        force = true;
        source = "${dev-sidecar}/dev-sidecar.ca.crt";
      };
      ".dev-sidecar/dev-sidecar.ca.key.pem" = {
        force = true;
        source = "${dev-sidecar}/dev-sidecar.ca.key.pem";
      };
    };
    activation.DevSidecarSettings = pkgs.mergeJson ".dev-sidecar/setting.json" {
      overwall = true;
    };
  };

  security.pki.certificateFiles = [
    "${dev-sidecar}/dev-sidecar.ca.crt"
  ];
}
