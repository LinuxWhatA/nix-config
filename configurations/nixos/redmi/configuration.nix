{ flake, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    flake.config.nixosModules.hardware.boot
  ];

  # BIOS DSDT 修复（PPPB buffer 越界，见 packages/redmi-acpi-table）
  # 未压缩 cpio 必须位于 initrd 最前，内核 ACPI 表升级机制才能识别
  boot.initrd.prepend = [
    "${pkgs.redmi-acpi-table}/acpi_override.cpio"
  ];

  boot.kernelParams = [
    # FIXME: amdgpu 7.0.13+ 内核回归（Rembrandt APU gfx ring timeout）缓解，
    "amdgpu.cwsr_enable=0"
  ];

  networking.hostName = "redmi";
}
