# homeModules.default —— 用户态基础（NixOS / darwin / 非 NixOS 通用）
# 分类：cli/ = 命令行日常，gui/ = 图形应用
{ flake, ... }:

let
  inherit (flake) inputs;
in
{
  imports = [
    inputs.nix-index-database.homeModules.nix-index
  ];

  xdg.userDirs.enable = true;
  xdg.userDirs.createDirectories = true;
  xdg.userDirs.setSessionVariables = false;
}
