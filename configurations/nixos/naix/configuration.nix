{ flake, ... }:

{
  imports = [
    ./hardware-configuration.nix
    flake.config.nixosModules.hardware.boot
  ];

  networking.hostName = "naix";
  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "26.11";

  users.mutableUsers = true;
  home-manager.users.${flake.config.me.username}.home.stateVersion = "26.11";
}
