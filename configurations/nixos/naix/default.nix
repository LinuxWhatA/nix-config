# naix 主机
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

    (self + /modules/nixos/base)
    (self + /modules/nixos/services/networking.nix)
    (self + /modules/nixos/services/pipewire.nix)
    (self + /modules/nixos/desktop/console.nix)
    (self + /modules/nixos/hardware/persist.nix)
    (self + /modules/nixos/gui/clash.nix)
    (self + /modules/nixos/gui/plymouth.nix)
    (self + /modules/nixos/gui/steam.nix)
    (self + /modules/nixos/hardware/graphics.nix)
    (self + /modules/nixos/hardware/bluetooth.nix)
    (self + /modules/nixos/virtualization/qemu.nix)
    (self + /modules/nixos/virtualization/waydroid.nix)
    (self + /modules/nixos/desktop/plasma6.nix)

    ./grub.nix
    ./configuration.nix
  ];

  home-manager.users.${flake.config.me.username}.imports = [
    self.homeModules.default
    self.homeModules.cli
  ];
}
