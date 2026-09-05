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

  # bitland-mifs-wmi（MIFS 控制 WMI）注册的 ACPI platform_profile 会把
  # power-profiles-daemon 从 amd_pstate EPP 抢走，改走 WMI 档位；该档位在本机
  # 不可靠：低功耗写入静默不生效、性能档硬性要求圆口 DC 供电（USB-C 充电机型
  # 恒 EOPNOTSUPP），档位会卡死在 balanced。屏蔽后 ppd 回落 amd_pstate EPP，
  # 三档均可切换；代价是 MIFS 键盘背光 LED 与风扇/温度 hwmon 一并停用，
  # 热键仍由 redmi-wmi 处理、不受影响。
  boot.blacklistedKernelModules = [ "bitland_mifs_wmi" ];

  networking.hostName = "redmi";
}
