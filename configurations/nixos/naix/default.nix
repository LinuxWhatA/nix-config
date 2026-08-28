# naix 主机
{ flake, ... }:
let
  inherit (flake) inputs;
in
{
  imports = [
    inputs.hardware.nixosModules.common-pc
    inputs.hardware.nixosModules.common-pc-ssd
    inputs.hardware.nixosModules.common-gpu-amd
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-cpu-amd-pstate
    inputs.hardware.nixosModules.common-cpu-amd-zenpower

    flake.config.nixosModules.desktop-host
    flake.config.nixosModules.virtualization.waydroid

    ./grub.nix
    ./configuration.nix
  ];
}
