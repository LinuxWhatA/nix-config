{ flake, pkgs, ... }:

{
  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = false;
      dedicatedServer.openFirewall = false;

      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };
    gamemode.enable = true;
    gamescope.enable = true;
  };

  hardware.steam-hardware.enable = true;

  users.users.${flake.config.me.username}.extraGroups = [ "gamemode" ];
}
