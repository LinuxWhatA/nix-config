# 用户接入：任意主机一行导入本文件即可获得
#   - 普通用户默认项（其余设置由导入方按需指定）
#   - home-manager 系统内托管
#   - 注：用户模块注入必须在各主机各自的 home-manager.users.<name>.imports 中
#     写明（HM 的该选项不接受 mkDefault/mkForce 包装，无法集中设默认值）
{ flake, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
  user = config.me.username;
in
{
  users.users.${user}.isNormalUser = lib.mkDefault true;
  home-manager.backupFileExtension = "hm-backup";
  home-manager.sharedModules = [ self.homeModules.default ];
}
