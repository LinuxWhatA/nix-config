{
  lib,
  inputs,
  ...
}:

rec {
  imports = [ inputs.disko.nixosModules.disko ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [
    "kvm-amd"
    "nct6775"
  ];
  boot.extraModulePackages = [ ];

  disko.devices.disk.main = {
    imageSize = "32G";
    type = "disk";
    device = "/dev/disk/by-diskseq/1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          size = "512M";
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
  fileSystems."/" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "noatime"
      "mode=755"
    ];
  };
  fileSystems."/persist".neededForBoot = true;

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
      "users"
      "nodev"
      "nofail"
      "nocase"
      "nosuid"
      "uid=1000"
      "gid=100"
      "umask=000"
      "x-gvfs-show"
      "big_writes"
      "windows_names"
    ];
  };

  fileSystems."/mnt/TiPlus5000" = {
    device = "/dev/disk/by-label/TiPlus5000";
    fsType = "ntfs";
    options = fileSystems."/mnt/Files".options;
  };

  services.btrfs.autoScrub.enable = true;
  services.btrfs.autoScrub.fileSystems = [ "/" ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp34s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
