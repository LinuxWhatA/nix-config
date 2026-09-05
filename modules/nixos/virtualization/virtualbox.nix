{ flake, ... }:

{
  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ "${flake.config.me.username}" ];
}
