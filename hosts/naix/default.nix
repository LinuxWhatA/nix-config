{
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-gpu-amd
    inputs.hardware.nixosModules.common-pc-ssd

    ./grub.nix
    ./hardware-configuration.nix

    ../common/global
    ../common/users/lwa

    ../common/optional/kde.nix
    ../common/optional/swap.nix
    ../common/optional/wireless.nix
    ../common/optional/pipewire.nix
    ../common/optional/plymouth.nix

    ../common/optional/hosts.nix
    ../common/optional/steam.nix
    ../common/optional/v2raya.nix

    ../common/optional/qemu.nix
    ../common/optional/waydroid.nix
    ../common/optional/proxychains.nix
  ];

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "lwa";

  my.kmscon.enable = true;
  my.kmscon.autologinUser = "lwa";

  networking.hostName = "naix";

  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_xanmod_latest;
    binfmt.emulatedSystems = [
      "aarch64-linux"
      "i686-linux"
    ];
  };

  programs = {
    adb.enable = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      amdvlk
    ];
    extraPackages32 = with pkgs; [
      driversi686Linux.amdvlk
    ];
  };

  system.stateVersion = "24.11";
}
