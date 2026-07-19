{ flake, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  users.mutableUsers = true;

  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
  };

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "test";
  system.stateVersion = "26.11";
}
