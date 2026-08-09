# wsl 主机 —— 组合清单
# 规则：需要什么才导入什么，一行一个文件
#   全部文件按分类存放，无自动接线 → 一律 (self + /modules/nixos/<分类>/<文件>.nix)
#   新增功能 = 分类目录内新建文件 + 本文件加一行
{ flake, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    ./configuration.nix
    inputs.nixos-wsl.nixosModules.wsl

    # 基础（base/，整目录导入；WSL 无 getty/persist/networking）
    (self + /modules/nixos/base)

    # 开发环境（cli/）
    (self + /modules/nixos/cli/fonts.nix)
    (self + /modules/nixos/cli/nix-ld.nix)
    (self + /modules/nixos/cli/packages.nix)
    (self + /modules/nixos/cli/pipewire.nix)
  ];

  # 系统内 home-manager 用户模块
  home-manager.users.lwa.imports = [
    self.homeModules.default
    self.homeModules.cli
  ];
}
