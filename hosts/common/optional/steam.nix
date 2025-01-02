{ pkgs, ... }:

{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = false;
    dedicatedServer.openFirewall = false;

    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };
}
