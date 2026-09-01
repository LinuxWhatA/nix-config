{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_zen;

  networking.hostName = "test";
}
