# redmi 硬件差异（内核、参数、数据盘）；公共 btrfs+tmpfs 布局在 hardware.btrfsRoot
{ flake, lib, ... }:
{
  imports = [ flake.config.nixosModules.hardware.btrfs-root ];

  hardware.btrfsRoot = {
    enable = true;
    device = "/dev/nvme0n1";
    swapSize = "16G";
  };

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ "ntfs" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.kernelParams = [
    "amdgpu.abmlevel=0"
    "acpi.ec_no_wakeup=1"
    "no_console_suspend"
  ];

  fileSystems."/mnt/Data" = {
    device = "/dev/disk/by-label/Data";
    fsType = "ntfs";
    options = [
      "defaults"
      "nodev" # 禁止设备文件
      "nocase" # 忽略大小写
      "nosuid" # 禁止 suid 位
      "nofail" # 启动时挂载失败不卡系统
      "uid=1000" # 映射所有者为你的用户
      "gid=100" # 映射组为 users 组
      "dmask=022" # 目录权限: 755
      "fmask=133" # 文件权限: 644
      "x-gvfs-show" # 在文件管理器中显示盘符
      "windows_names" # 提高与Windows的兼容性
      "noauto"
      "x-systemd.automount"
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=10s"
    ];
  };

  networking.useDHCP = lib.mkDefault true;
}
