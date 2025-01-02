{ config, ... }:

{
  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ "${config.home.username}" ];

  # virtualisation.virtualbox.host.enableExtensionPack = true;
}
