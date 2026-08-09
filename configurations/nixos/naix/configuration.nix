{ flake, ... }:

{
  imports = [
    ./hardware-configuration.nix
    (flake.inputs.self + /modules/nixos/hardware/boot.nix)
  ];

  networking.hostName = "naix";
  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "26.11";

  home-manager.users.lwa.home.stateVersion = "26.11";
}
