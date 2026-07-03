{ flake, ... }:

{
  services.getty.autologinUser = flake.config.me.username;

  console.enable = true;
  console.font = "MesloLGS NF";
}
