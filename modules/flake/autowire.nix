# 轻量 autowiring（替代外部 nixos-unified.flakeModules.autoWire）
#
# 规则：
#   configurations/nixos/*.nix → nixosConfigurations   （NixOS + home-manager）
#   modules/nixos/*.nix        → nixosModules
#   modules/home/*.nix         → homeModules
#   overlays/*.nix             → overlays
#   packages/*.nix             → packages
#
# 同时提供统一 specialArgs：flake = { self, inputs, config }，
# 使配置里可以直接写 { flake, ... } 拿到 inputs / self / config.me。仅支持 Linux。
{ self, inputs, config, lib, ... }:
let
  # 传给 NixOS / home-manager 模块的 specialArgs
  specialArgsFor = rec {
    common = { flake = { inherit self inputs config; }; };
    nixos = common;
  };

  # home-manager 通用默认值（home-manager 2.x 不再自动设置 homeDirectory）
  homeModules = {
    common = { config, lib, ... }: {
      home.homeDirectory = lib.mkDefault "/home/${config.home.username}";
    };
  };

  # NixOS 系统 + 内置 home-manager 接线
  mkNixosSystem =
    { home-manager ? false }:
    mod:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = specialArgsFor.nixos;
      modules =
        [ mod ]
        ++ lib.optional home-manager {
          imports = [
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = specialArgsFor.nixos;
              home-manager.sharedModules = [ homeModules.common ];
            }
          ];
        };
    };

  # 目录扫描：顶层 *.nix 或含 default.nix 的子目录，取文件名作为属性名。
  # f 返回 null 则跳过。
  mapAttrsMaybe = f: attrs:
    lib.pipe attrs [
      (lib.mapAttrsToList f)
      (builtins.filter (x: x != null))
      builtins.listToAttrs
    ];
  forAllNixFiles = dir: f:
    if builtins.pathExists dir then
      lib.pipe dir [
        builtins.readDir
        (mapAttrsMaybe (name: type:
          if type == "regular" then
            let name' = lib.removeSuffix ".nix" name; in
            if name' != name then lib.nameValuePair name' (f "${dir}/${name}")
            else null
          else if type == "directory" && builtins.pathExists "${dir}/${name}/default.nix" then
            lib.nameValuePair name (f "${dir}/${name}")
          else null))
      ]
    else { };
in
{
  flake = {
    nixosConfigurations =
      forAllNixFiles "${self}/configurations/nixos"
        (fn: mkNixosSystem { home-manager = true; } fn);
    nixosModules =
      forAllNixFiles "${self}/modules/nixos" (fn: fn);
    homeModules =
      forAllNixFiles "${self}/modules/home" (fn: fn);
    overlays =
      forAllNixFiles "${self}/overlays" (fn: import fn specialArgsFor.common);
  };

  perSystem = { pkgs, ... }: {
    packages =
      forAllNixFiles "${self}/packages" (fn: pkgs.callPackage fn { });
  };
}