# 接线（wiring）：扫描目录生成 flake outputs，并把低层模块收集到顶层 config 的
# nixosModules / homeModules 选项（dendritic 装配点，主机从 config 引用）。
#
# 规则（scanTree 借鉴 vic/import-tree：递归 + 结构保留，目录 → 嵌套 attrset，
# default.nix 即键 "default"）：
#   configurations/nixos/<host>/default.nix → nixosConfigurations.<host>
#   modules/nixos/<dir>/<file>.nix           → nixosModules.<dir>.<file>（如 nixosModules.desktop.plasma6）
#   modules/nixos/<dir>/default.nix          → nixosModules.<dir>.default（bundle，如 base）
#   modules/home/<dir>/<file>.nix            → homeModules.<dir>.<file>（如 homeModules.gui.opencode）
#   modules/home/<dir>/default.nix           → homeModules.<dir>.default（bundle，如 cli）
#   overlays/<name>.nix                      → overlays.<name>
# 嵌套结构天然无同名冲突（如 cli/packages.nix 与 gui/packages.nix 分属不同键）。
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
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = specialArgs;
            sharedModules = [ homeCommon ];
          };
        }
      ];
    };

  # 一层扫描：顶层 .nix 文件，或含 default.nix 的目录
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

  # 递归导入目录树为嵌套 attrset（借鉴 vic/import-tree）：
  #   目录 → 子 attrset；.nix 文件 → 去后缀为键；default.nix 即键 "default"。
  # 结构保留、任意深度、无同名冲突。
  scanTree =
    dir: f:
    let
      recurse =
        path:
        lib.mapAttrs'
          (
            name: type:
            if type == "directory" then
              lib.nameValuePair name (recurse "${path}/${name}")
            else
              lib.nameValuePair (lib.removeSuffix ".nix" name) (f "${path}/${name}")
          )
          (
            lib.filterAttrs (name: type: type == "directory" || lib.hasSuffix ".nix" name) (
              builtins.readDir path
            )
          );
    in
    if builtins.pathExists dir then recurse dir else { };
in
{
  options = {
    nixosModules = lib.mkOption {
      type = lib.types.attrsOf lib.types.raw;
      default = { };
      description = "NixOS 模块树（目录 → 嵌套 attrset，default.nix 为 .default），主机经 flake.config.nixosModules.* 引用";
    };

    homeModules = lib.mkOption {
      type = lib.types.attrsOf lib.types.raw;
      default = { };
      description = "Home-manager 模块树（目录 → 嵌套 attrset），主机经 flake.config.homeModules.* 引用";
    };
  };

  config = {
    nixosModules = scanTree "${self}/modules/nixos" (fn: fn);
    homeModules = scanTree "${self}/modules/home" (fn: fn);

    flake = {
      nixosConfigurations = scan "${self}/configurations/nixos" mkNixosSystem;
      overlays = scan "${self}/overlays" (fn: import fn specialArgs);
    };
  };
}
