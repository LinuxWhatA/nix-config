{ flake, pkgs, ... }:

let
  inherit (pkgs) dev-sidecar;
  mergeJson = (import (flake.inputs.self + /lib/merge-json.nix) { inherit pkgs; }).mergeJson;
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
    activation.DevSidecarSettings = mergeJson ".dev-sidecar/setting.json" (
      builtins.toJSON {
        overwall = true;
      }
    );
  };

  security.pki.certificateFiles = [
    "${dev-sidecar}/dev-sidecar.ca.crt"
  ];
}
