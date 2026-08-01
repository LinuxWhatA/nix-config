{ flake, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    inputs.hardware.nixosModules.common-pc-laptop
    inputs.hardware.nixosModules.common-pc-laptop-ssd
    inputs.hardware.nixosModules.common-gpu-amd
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-cpu-amd-pstate
    inputs.hardware.nixosModules.common-cpu-amd-zenpower

    ./grub.nix
    ./configuration.nix
    self.nixosModules.default
    (self + /modules/nixos/gui/plasma6.nix)
    (self + /modules/nixos/optional/qemu.nix)
    (self + /modules/nixos/optional/clash.nix)
  ];
}
