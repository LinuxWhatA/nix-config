{ flake, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.hardware.nixosModules.common-gpu-nvidia
    inputs.hardware.nixosModules.common-pc-laptop
    inputs.hardware.nixosModules.common-pc-laptop-ssd

    self.nixosModules.default
    (self + /modules/nixos/gui/plasma6.nix)
    (self + /modules/nixos/optional/nvidia_470.nix)
    ./configuration.nix
  ];
}
