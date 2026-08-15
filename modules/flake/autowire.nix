# 目录扫描自动生成 flake outputs，同时提供统一 specialArgs
#
# 约束：不得为本文件添加任何新功能——需保持与 nixos-unified 的 Autowiring
# 功能一致。新 output/接线逻辑一律以独立模块放在 modules/flake/ 下。
#
# 规则：
#   configurations/nixos/*.nix → nixosConfigurations  （NixOS + home-manager）
#   modules/nixos/*.nix        → nixosModules
#   modules/home/*.nix         → homeModules
#   overlays/*.nix             → overlays
#   packages/*.nix             → packages
#
{
  self,
  inputs,
  config,
  lib,
  ...
}:
let
  specialArgs = {
    flake = { inherit self inputs config; };
  };

  homeCommon = { config, lib, ... }: {
    home.homeDirectory = lib.mkDefault "/home/${config.home.username}";
  };

  mkNixosSystem =
    mod:
    inputs.nixpkgs.lib.nixosSystem {
      inherit specialArgs;
      modules = [
        mod
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = specialArgs;
          home-manager.sharedModules = [ homeCommon ];
        }
      ];
    };

  scan =
    dir: f:
    if builtins.pathExists dir then
      lib.listToAttrs (
        lib.concatMap (
          name:
          lib.optionals (lib.hasSuffix ".nix" name || builtins.pathExists "${dir}/${name}/default.nix") [
            (lib.nameValuePair (lib.removeSuffix ".nix" name) (f "${dir}/${name}"))
          ]
        ) (builtins.attrNames (builtins.readDir dir))
      )
    else
      { };
in
{
  flake = {
    nixosConfigurations = scan "${self}/configurations/nixos" mkNixosSystem;
    nixosModules = scan "${self}/modules/nixos" (fn: fn);
    homeModules = scan "${self}/modules/home" (fn: fn);
    overlays = scan "${self}/overlays" (fn: import fn specialArgs);
  };

  perSystem = { pkgs, ... }: {
    packages = scan "${self}/packages" (fn: pkgs.callPackage fn { });
  };
}
