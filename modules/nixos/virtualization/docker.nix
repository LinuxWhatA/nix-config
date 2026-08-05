# Docker —— 主机配置一行导入：(self + /modules/nixos/virtualization/docker.nix)
{ flake, ... }:
{
  virtualisation.docker.enable = true;

  users.users.${flake.config.me.username}.extraGroups = [ "docker" ];
}
