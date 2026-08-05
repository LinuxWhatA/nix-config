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
    (self + /modules/nixos/cli/fonts.nix)
    (self + /modules/nixos/cli/getty.nix)
    (self + /modules/nixos/cli/home.nix)
    (self + /modules/nixos/cli/locale.nix)
    (self + /modules/nixos/cli/networking.nix)
    (self + /modules/nixos/cli/nix-ld.nix)
    (self + /modules/nixos/cli/nix.nix)
    (self + /modules/nixos/cli/openssh.nix)
    (self + /modules/nixos/cli/packages.nix)
    (self + /modules/nixos/cli/persist.nix)
    (self + /modules/nixos/cli/pipewire.nix)
    (self + /modules/nixos/cli/security.nix)
    (self + /modules/nixos/cli/swap.nix)
    (self + /modules/nixos/cli/vim.nix)

    (self + /modules/nixos/desktop/plasma6.nix)

    (self + /modules/nixos/gui/clash.nix)
    (self + /modules/nixos/gui/plymouth.nix)
    (self + /modules/nixos/gui/steam.nix)

    (self + /modules/nixos/hardware/bluetooth.nix)
    (self + /modules/nixos/hardware/hardware.nix)

    (self + /modules/nixos/virtualization/qemu.nix)
  ];
}
