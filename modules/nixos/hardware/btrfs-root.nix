# btrfs + tmpfs 根布局（disko），实机主机共用的磁盘骨架。
#
# disko 建 ESP 与 btrfs 子卷（/home、/persist、/nix、/swap），/ 为 tmpfs，
# impermanence 的持久化落在 /persist（见 persist.nix）。主机只需填 device 与
# swap 大小；label 不参与运行期解析，固定即可。内核段、ntfs 数据盘等硬件事实
# 与布局无关，留在各主机的 hardware-configuration。
{
  flake,
  lib,
  config,
  ...
}:
let
  cfg = config.hardware.btrfsRoot;
in
{
  options.hardware.btrfsRoot = {
    enable = lib.mkEnableOption "btrfs + tmpfs 根布局（disko）";
    device = lib.mkOption {
      type = lib.types.str;
      description = "disko 根盘 device";
    };
    swapSize = lib.mkOption {
      type = lib.types.str;
      default = "8G";
      description = "/swap 子卷 swapfile 大小";
    };
  };

  # disko 的 option 必须随模块合并（不能放在 mkIf 内延迟 import）
  imports = [ flake.inputs.disko.nixosModules.disko ];

  config = lib.mkIf cfg.enable {
    disko.devices.disk.main = {
      type = "disk";
      inherit (cfg) device;
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
                  swap.swapfile.size = cfg.swapSize;
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

    services.btrfs.autoScrub = {
      enable = true;
      fileSystems = [
        "/nix"
        "/home"
        "/persist"
      ];
    };
  };
}
