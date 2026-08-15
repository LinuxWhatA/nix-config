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
  environment.etc."nixos".source = flake.inputs.self;
  nixpkgs = {
    config = {
      allowUnfree = true;
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
      impure-env = [
        "http_proxy"
        "https_proxy"
      ];
      warn-dirty = false;

      # 镜像不可用时回退本地构建
      fallback = true;

      substituters = lib.mkDefault [
        "https://mirror.nju.edu.cn/nix-channels/store"
        "https://mirrors.ustc.edu.cn/nix-channels/store"
        "https://mirror.sjtu.edu.cn/nix-channels/store"
        # "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      ];
    };
  };
}
