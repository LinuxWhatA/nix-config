# See /modules/nixos/* for actual settings
# This file is just *top-level* configuration.
{ flake, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    inputs.hardware.nixosModules.common-pc
    inputs.hardware.nixosModules.common-pc-ssd
    inputs.hardware.nixosModules.common-gpu-amd
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-cpu-amd-pstate
    inputs.hardware.nixosModules.common-cpu-amd-zenpower

    self.nixosModules.default
    (self + /modules/nixos/gui/gnome.nix)
    (self + /modules/nixos/optional/qemu.nix)
    (self + /modules/nixos/optional/waydroid.nix)
    ./grub.nix
    ./configuration.nix
  ];
}
