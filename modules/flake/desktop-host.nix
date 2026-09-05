# 桌面主机功能组合（dendritic）：在顶层 config 中把桌面特性合并为一个
# deferredModule（nixosModules.desktop-host），主机只需一行导入：
#   flake.config.nixosModules.desktop-host
# 硬件差异（common-pc-* vs common-pc-laptop-*）、waydroid、grub 保留在各主机 default.nix
{ config, ... }:
let
  inherit (config) nixosModules homeModules;
  me = config.me.username;
in
{
  nixosModules.desktop-host = {
    imports = [
      nixosModules.base.default
      nixosModules.desktop.console
      nixosModules.desktop.labwc
      nixosModules.gui.thunar
      nixosModules.gui.clash
      nixosModules.gui.steam
      nixosModules.hardware.bluetooth
      nixosModules.hardware.graphics
      nixosModules.hardware.persist
      nixosModules.services.fwupd
      nixosModules.services.networking
      nixosModules.services.pipewire
      nixosModules.virtualization.qemu
    ];

    home-manager.users.${me}.imports = [
      homeModules.cli.default
      homeModules.gui.default
    ];
  };
}
