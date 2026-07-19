{
  flake,
  lib,
  ...
}:

let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  nixpkgs = {
    config = {
      allowUnfree = true;
      allowBroken = true;
      allowUnsupportedSystem = true;
    };
    overlays = lib.attrValues self.overlays;
  };

  nix = {
    channel.enable = false;

    settings = {
      trusted-users = [
        "root"
        "@wheel"
      ];
      allowed-users = [
        "root"
        "@users"
      ];
      auto-optimise-store = lib.mkDefault true;
      experimental-features = [
        "flakes"
        "nix-command"
        "ca-derivations"
        "configurable-impure-env"
      ];
      warn-dirty = false;

      substituters = lib.mkForce [
        "https://mirror.nju.edu.cn/nix-channels/store"
        "https://mirrors.ustc.edu.cn/nix-channels/store"
        "https://mirror.sjtu.edu.cn/nix-channels/store"
        # "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      ];
    };
  };
}
