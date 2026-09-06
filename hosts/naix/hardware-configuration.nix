# naix 硬件差异（内核、数据盘、VM 变体）；公共 btrfs+tmpfs 布局在 hardware.btrfsRoot
{ flake, lib, ... }:
rec {
  imports = [ flake.config.nixosModules.hardware.btrfs-root ];

  hardware.btrfsRoot = {
    enable = true;
    device = "/dev/disk/by-diskseq/1";
    swapSize = "8G";
  };

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "sd_mod"
  ];
  boot.kernelModules = [
    "kvm-amd"
    "nct6775"
  ];

  # nix build .#nixosConfigurations.naix.config.system.build.vmWithDisko
  virtualisation.vmVariantWithDisko = {
    virtualisation = {
      fileSystems."/persist".neededForBoot = true;
      memorySize = 8192;
      cores = 6;
    };
  };

  fileSystems."/mnt/Files" = {
    device = "/dev/disk/by-label/Files";
    fsType = "ntfs";
    options = [
      "defaults"
      "nodev" # 禁止设备文件
      "nosuid" # 禁止 suid 位
      "nofail" # 启动时挂载失败不卡系统
      "uid=1000" # 映射所有者为你的用户
      "gid=100" # 映射组为 users 组
      "umask=000" # 所有用户可读可写可执行
      "x-gvfs-show" # 在文件管理器中显示盘符
      # "noacsrules" # 忽略 Windows ACL
    ];
  };

  fileSystems."/mnt/TiPlus5000" = {
    device = "/dev/disk/by-label/TiPlus5000";
    fsType = "ntfs";
    options = fileSystems."/mnt/Files".options;
  };

  networking.useDHCP = lib.mkDefault true;
}
