{ flake, lib, ... }:

{
  services.getty.autologinUser = lib.mkForce flake.config.me.username;

  console.enable = true;
  console.font = "MesloLGS NF";
}
