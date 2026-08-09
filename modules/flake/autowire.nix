# 轻量 autowiring（替代外部 nixos-unified.flakeModules.autoWire）
#
# 规则：
#   configurations/nixos/*.nix → nixosConfigurations  （NixOS + home-manager）
#   modules/nixos/*.nix        → nixosModules
#   modules/home/*.nix         → homeModules
#   overlays/*.nix             → overlays
#   packages/*.nix             → packages
#
# 同时提供统一 specialArgs：flake = { self, inputs, config }，
# 使配置里可以直接写 { flake, ... } 拿到 inputs / self / config.me。仅支持 Linux。
{
  self,
  inputs,
  config,
  lib,
  ...
}:
let
  # 传给 NixOS / home-manager 模块的 specialArgs
  specialArgs = {
    flake = { inherit self inputs config; };
  };

  # home-manager 通用默认值（home-manager 2.x 不再自动设置 homeDirectory）
  homeCommon = { config, lib, ... }: {
    home.homeDirectory = lib.mkDefault "/home/${config.home.username}";
  };

  # NixOS 系统 + 内置 home-manager 接线
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

  # 目录扫描：顶层 *.nix 或含 default.nix 的子目录，取文件名/目录名作为属性名。
  # f 返回 null 则跳过。
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
