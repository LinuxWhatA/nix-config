# lwa@wsl 用户态 —— 组合清单
# 分类模块（modules/home/ 下各目录）：
#   default = 用户基础（xdg 目录 / stateVersion / nix-index）
#   cli     = 命令行日常（shell / git / direnv / nix / 包）
#   gui     = 图形应用（WSL 无桌面，不导入）
{ flake, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    self.homeModules.default
    self.homeModules.cli
  ];

  home.username = "lwa";
  _module.args.hostname = "wsl";
  home.stateVersion = "26.11";
}
