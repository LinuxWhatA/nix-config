{ flake, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  users.mutableUsers = true;

  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    binfmt.emulatedSystems = [
      "aarch64-linux"
      "i686-linux"
    ];
    supportedFilesystems = [ "ntfs" ];
  };

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "redmi";
  system.stateVersion = "26.11";
}
