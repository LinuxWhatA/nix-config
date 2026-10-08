# Top-level configuration for everything in this repo.
{
  lib,
  self,
  ...
}:
let
  userSubmodule = lib.types.submodule {
    options = {
      username = lib.mkOption {
        type = lib.types.str;
      };
      fullname = lib.mkOption {
        type = lib.types.str;
      };
      email = lib.mkOption {
        type = lib.types.str;
      };
      sshKey = lib.mkOption {
        type = lib.types.str;
        description = ''
          SSH public key
        '';
      };
    };
  };
in
{
  imports = [
    ../../config.nix
  ];
  options = {
    me = lib.mkOption {
      type = userSubmodule;
    };

    # 构造 pkgs 的公共参数：系统侧（base/pkgs.nix）与 flake 侧（per-system.nix）
    # 都从这里取，否则两边各写一遍 overlays/allowUnfree，产物会与系统里装的分叉
    pkgsArgs = lib.mkOption {
      type = lib.types.attrsOf lib.types.raw;
      default = {
        overlays = builtins.attrValues self.overlays;
        config.allowUnfree = true;
      };
      description = "Common arguments for importing nixpkgs";
    };
  };
}
