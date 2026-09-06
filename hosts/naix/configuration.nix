{ flake, ... }:

{
  imports = [
    ./hardware-configuration.nix
    flake.config.nixosModules.hardware.boot
  ];

  networking.hostName = "naix";
}
