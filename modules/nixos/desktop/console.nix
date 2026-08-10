{ flake, lib, ... }:

{
  services.getty.autologinUser = lib.mkForce flake.config.me.username;
  console.font = "Lat2-Terminus16";
}
