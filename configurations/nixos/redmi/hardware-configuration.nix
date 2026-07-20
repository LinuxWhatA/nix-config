{
  flake,
  lib,
  ...
}:

{
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

  fileSystems."/mnt/TiPlus5000" = {
    device = "/dev/disk/by-label/TiPlus5000";
    fsType = "ntfs3";
    options = [
      "defaults"
      "force"
      "nodev" # 禁止设备文件
      "nosuid" # 禁止 suid 位
      "nofail" # 启动时挂载失败不卡系统
      "uid=1000" # 映射所有者为你的用户
      "gid=100" # 映射组为 users 组
      "dmask=0000" # 目录777
      "fmask=0000" # 文件777
      "x-gvfs-show" # 在文件管理器中显示盘符
    ];
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
