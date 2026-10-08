# redmi 本机差异：硬件配置 + 启动链 + GRUB 差异项 + ACPI/黑名单（集中在此，不再拆 grub.nix）
{ flake, pkgs, ... }:

let
  # 源码编译的 a1 GRUB（grub-mkimage + x86_64-efi 模块 + builtin.txt + bootmgfw.efi）
  a1ive = pkgs.a1ive-grub;
  bin = pkgs.coreutils + "/bin";
in
{
  imports = [
    ./hardware-configuration.nix
    flake.config.nixosModules.hardware.boot
    flake.config.nixosModules.hardware.grub
  ];

  boot = {
    loader = {
      timeout = 5;
      grub = {
        extraConfig = "set enable_progress_indicator=0";
        extraInstallCommands = ''
          # 模块与字体（源码编译产物）
          ${bin}/cp -rf ${a1ive}/lib/grub/x86_64-efi /boot/grub/
          ${bin}/mkdir -p /boot/grub/fonts
          ${bin}/cp -f ${a1ive}/share/grub/*.pf2 /boot/grub/fonts/

          # ntboot --efi 需要 bootmgfw.efi
          ${bin}/cp -f ${a1ive}/bootmgfw.efi /boot/grub/

          # core image
          ${bin}/cp -f ${a1ive}/grubx64.efi /boot/EFI/NixOS-boot/
        '';
        extraEntries = ''
          menuentry "Windows" --class windows {
            savedefault
            search -s -f /OS/Windows.vhd
            ntboot --vhd --efi="''${prefix}/bootmgfw.efi" "/OS/Windows.vhd";
          }

          menuentry "Windows 11" --class windows {
            savedefault
            search -s -f /OS/Windows11.vhd
            ntboot --vhd --efi="''${prefix}/bootmgfw.efi" "/OS/Windows11.vhd";
          }

          menuentry "WePE" --class windows {
            search -s -f /OS/WePE_64_V2.3.iso
            map -f /OS/WePE_64_V2.3.iso;
          }

          menuentry "Reboot (R)" --hotkey "r" {
            reboot;
          }

          menuentry "Halt (H)" --hotkey "h" {
            halt;
          }
        '';
      };
    };

    # BIOS DSDT 修复（PPPB buffer 越界，见 packages/redmi-acpi-table）
    # 未压缩 cpio 必须位于 initrd 最前，内核 ACPI 表升级机制才能识别
    initrd.prepend = [
      "${pkgs.redmi-acpi-table}/acpi_override.cpio"
    ];

    # bitland-mifs-wmi（MIFS 控制 WMI）注册的 ACPI platform_profile 会把
    # power-profiles-daemon 从 amd_pstate EPP 抢走，改走 WMI 档位；该档位在本机
    # 不可靠：低功耗写入静默不生效、性能档硬性要求圆口 DC 供电（USB-C 充电机型
    # 恒 EOPNOTSUPP），档位会卡死在 balanced。屏蔽后 ppd 回落 amd_pstate EPP，
    # 三档均可切换；代价是 MIFS 键盘背光 LED 与风扇/温度 hwmon 一并停用，
    # 热键仍由 redmi-wmi 处理、不受影响。
    blacklistedKernelModules = [ "bitland_mifs_wmi" ];
  };

  networking.hostName = "redmi";
}
