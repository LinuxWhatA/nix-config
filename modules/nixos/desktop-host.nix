# naix/redmi 桌面主机公共组合，主机配置一行导入：(self + /modules/nixos/desktop-host.nix)
# 硬件差异（common-pc-* vs common-pc-laptop-*）、waydroid、grub 保留在各主机 default.nix
{ flake, ... }:
{
  imports = [
    (flake.inputs.self + /modules/nixos/desktop/console.nix)
    (flake.inputs.self + /modules/nixos/desktop/plasma6.nix)
    (flake.inputs.self + /modules/nixos/gui/clash.nix)
    (flake.inputs.self + /modules/nixos/gui/plymouth.nix)
    (flake.inputs.self + /modules/nixos/gui/steam.nix)
    (flake.inputs.self + /modules/nixos/hardware/bluetooth.nix)
    (flake.inputs.self + /modules/nixos/hardware/graphics.nix)
    (flake.inputs.self + /modules/nixos/hardware/persist.nix)
    (flake.inputs.self + /modules/nixos/services/networking.nix)
    (flake.inputs.self + /modules/nixos/services/pipewire.nix)
    (flake.inputs.self + /modules/nixos/virtualization/qemu.nix)
  ];

  home-manager.users.${flake.config.me.username}.imports = [
    flake.inputs.self.homeModules.default
    flake.inputs.self.homeModules.cli
  ];
}
