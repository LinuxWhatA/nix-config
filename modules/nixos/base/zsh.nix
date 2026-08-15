# 系统 shell 属性：zsh 全套配置（插件、提示符、session 变量注入）已迁至 HM
# modules/home/cli/zsh.nix；本文件只保留系统级用户属性
{ pkgs, ... }:
{
  # 提供 zsh 的 PATH shim（/etc/profile.d），否则断言：
  # "users.users.*.shell is set to zsh, but programs.zsh.enable is not true"
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;
  users.users.root.shell = pkgs.zsh;
}
