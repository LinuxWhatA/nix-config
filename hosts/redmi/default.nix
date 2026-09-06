# redmi 主机
{ flake, ... }:
let
  inherit (flake) inputs;
in
{
  imports = [
    inputs.hardware.nixosModules.common-pc-laptop
    inputs.hardware.nixosModules.common-pc-laptop-ssd
    inputs.hardware.nixosModules.common-gpu-amd
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-cpu-amd-pstate
    inputs.hardware.nixosModules.common-cpu-amd-zenpower

    flake.config.nixosModules.desktop-host
    flake.config.nixosModules.virtualization.rdp-windows

    ./grub.nix
    ./configuration.nix
  ];
}
