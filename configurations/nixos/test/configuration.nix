{ flake, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_zen;
  users.mutableUsers = true;

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "test";
  system.stateVersion = "26.11";

  home-manager.users.${flake.config.me.username}.home.stateVersion = "26.11";
}
