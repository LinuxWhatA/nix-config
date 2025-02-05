{
  config,
  lib,
  ...
}:

{
  boot.initrd = {
    availableKernelModules = [
      "xhci_pci"
      "ahci"
      "sd_mod"
    ];
    kernelModules = [ "kvm-intel" ];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/00be4f47-8b8b-47ac-a287-e0eddeef7ab3";
    fsType = "btrfs";
    options = [
      "subvol=root"
      "compress-force=zstd:15"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/00be4f47-8b8b-47ac-a287-e0eddeef7ab3";
    fsType = "btrfs";
    options = [
      "subvol=nix"
      "compress-force=zstd:15"
      "noatime"
    ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/00be4f47-8b8b-47ac-a287-e0eddeef7ab3";
    fsType = "btrfs";
    options = [
      "subvol=home"
      "compress-force=zstd:15"
    ];
  };

  fileSystems."/swap" = {
    device = "/dev/disk/by-uuid/00be4f47-8b8b-47ac-a287-e0eddeef7ab3";
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

  swapDevices = [ { device = "/swap/swapfile"; } ];
  services.btrfs.autoScrub.enable = true;

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp2s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp3s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
