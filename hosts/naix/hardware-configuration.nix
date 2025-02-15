{
  config,
  lib,
  inputs,
  ...
}:

{
  imports = [ inputs.disko.nixosModules.disko ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-diskseq/1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          start = "1M";
          end = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        nixos = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-Lnixos" ];
            subvolumes = {
              "/root" = {
                mountOptions = [ "compress=zstd" ];
                mountpoint = "/";
              };
              "/home" = {
                mountOptions = [ "compress=zstd" ];
                mountpoint = "/home";
              };
              "/persist" = {
                mountOptions = [ "compress=zstd" ];
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
                swap.swapfile.size = "8G";
              };
            };
          };
        };
      };
    };
  };

  fileSystems."/persist".neededForBoot = true;

  fileSystems."/mnt/TiPlus5000" = {
    device = "/dev/disk/by-label/TiPlus5000";
    fsType = "ntfs";
    options = [
      "nofail"
      "nodev"
      "nocase"
      "uid=1000"
      "gid=100"
      "umask=0000"
      "fmask=0000"
      "dmask=0000"
    ];
  };

  fileSystems."/mnt/Files" = {
    device = "/dev/disk/by-label/Files";
    fsType = "ntfs";
    options = [
      "nofail"
      "nodev"
      "nocase"
      "uid=1000"
      "gid=100"
      "umask=0000"
      "fmask=0000"
      "dmask=0000"
    ];
  };

  swapDevices = [ { device = "/swap/swapfile"; } ];
  services.btrfs.autoScrub.enable = true;
  services.btrfs.autoScrub.fileSystems = [ "/" ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp34s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
