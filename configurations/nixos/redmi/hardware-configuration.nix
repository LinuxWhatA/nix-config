{
  flake,
  lib,
  ...
}:

rec {
  imports = [
    flake.inputs.disko.nixosModules.disko
  ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ "ntfs3" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];
  boot.kernelParams = [
    "amdgpu.abmlevel=0"
    "acpi.ec_no_wakeup=1"
    "no_console_suspend"
  ];

  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        NixOS = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-LNixOS" ];
            subvolumes = {
              "/home" = {
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
                mountpoint = "/home";
              };
              "/persist" = {
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
                mountpoint = "/persist";
              };
              "/nix" = {
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
                mountpoint = "/nix";
              };
              "/swap" = {
                mountOptions = [ "noatime" ];
                mountpoint = "/swap";
                swap.swapfile.size = "16G";
              };
            };
          };
        };
      };
    };
  };

  fileSystems."/" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "noatime"
      "mode=755"
    ];
  };
  fileSystems."/persist".neededForBoot = true;

  fileSystems."/mnt/Data" = {
    device = "/dev/disk/by-label/Data";
    fsType = "ntfs3";
    options = [
      "defaults"
      "force"
      "nodev" # 禁止设备文件
      "nocase" # 忽略大小写
      "nosuid" # 禁止 suid 位
      "nofail" # 启动时挂载失败不卡系统
      "uid=1000" # 映射所有者为你的用户
      "gid=100" # 映射组为 users 组
      "dmask=0000" # 目录777
      "fmask=0000" # 文件777
      "x-gvfs-show" # 在文件管理器中显示盘符
      "windows_names" # 提高与Windows的兼容性
      # 延迟挂载：不阻塞 local-fs.target，首次访问时自动挂载（节省 ~50ms + 避免无盘时卡启动）
      "noauto"
      "x-systemd.automount"
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=10s"
    ];
  };

  fileSystems."/mnt/Windows" = {
    device = "/dev/disk/by-label/Windows";
    fsType = "ntfs3";
    options = fileSystems."/mnt/Data".options;
  };

  services.btrfs.autoScrub.enable = true;
  services.btrfs.autoScrub.fileSystems = [
    "/nix"
    "/home"
    "/persist"
  ];

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
