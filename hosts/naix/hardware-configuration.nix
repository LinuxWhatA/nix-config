{
  config,
  lib,
  pkgs,
  ...
}:

{
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

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/0311cdf0-a4ea-4ad9-b35b-a79046cb0897";
    fsType = "btrfs";
    options = [
      "subvol=root"
      "compress=zstd"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/0311cdf0-a4ea-4ad9-b35b-a79046cb0897";
    fsType = "btrfs";
    options = [
      "subvol=nix"
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/0311cdf0-a4ea-4ad9-b35b-a79046cb0897";
    fsType = "btrfs";
    options = [
      "subvol=home"
      "compress=zstd"
    ];
  };

  fileSystems."/swap" = {
    device = "/dev/disk/by-uuid/0311cdf0-a4ea-4ad9-b35b-a79046cb0897";
    fsType = "btrfs";
    options = [
      "subvol=swap"
      "noatime"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/12CE-A600";
    fsType = "vfat";
  };

  fileSystems."/mnt/TiPlus5000" = {
    device = "/dev/disk/by-uuid/F604474D04470FD3";
    fsType = "ntfs";
    options = [
      "nofail"
      "nodev"
      "nocase"
      "noatime"
      "nodiratime"
      "relatime"
      "uid=1000"
      "gid=100"
      "umask=0000"
      "fmask=0000"
      "dmask=0000"
    ];
  };

  fileSystems."/mnt/Files" = {
    device = "/dev/disk/by-uuid/E4B6EF47B6EF18B6";
    fsType = "ntfs";
    options = [
      "nofail"
      "nodev"
      "nocase"
      "noatime"
      "nodiratime"
      "relatime"
      "uid=1000"
      "gid=100"
      "umask=0000"
      "fmask=0000"
      "dmask=0000"
    ];
  };

  swapDevices = [ { device = "/swap/swapfile"; } ];
  services.btrfs.autoScrub.enable = true;

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp34s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
