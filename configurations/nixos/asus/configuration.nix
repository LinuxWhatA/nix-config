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
  };

  boot.loader = {
    systemd-boot = {
      enable = true;
      consoleMode = "max";
    };
    efi.canTouchEfiVariables = true;
  };

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "asus";
  system.stateVersion = "25.11";
}
