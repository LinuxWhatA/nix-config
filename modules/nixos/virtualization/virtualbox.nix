# VirtualBox —— 主机配置一行导入：(self + /modules/nixos/virtualization/virtualbox.nix)
{ flake, ... }:

{
  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ "${flake.config.me.username}" ];

  # virtualisation.virtualbox.host.enableExtensionPack = true;
}
