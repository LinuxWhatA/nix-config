{
  flake,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    flake.inputs.disko.nixosModules.disko
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  disko.devices.disk.main = {
    imageSize = "32G";
    type = "disk";
    device = "/dev/sda";
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

  services.btrfs.autoScrub.enable = true;
  services.btrfs.autoScrub.fileSystems = [
    "/nix"
    "/home"
    "/persist"
  ];

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
