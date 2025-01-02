{
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.hardware.nixosModules.common-gpu-nvidia-disable
    inputs.hardware.nixosModules.common-pc-laptop
    inputs.hardware.nixosModules.common-pc-laptop-ssd

    ./hardware-configuration.nix

    ../common/global
    ../common/users/lwa

    ../common/optional/swap.nix
    ../common/optional/gnome.nix
    ../common/optional/wireless.nix
    ../common/optional/pipewire.nix
    ../common/optional/quietboot.nix
    ../common/optional/systemd-boot.nix

    ../common/optional/hosts.nix
    ../common/optional/steam.nix
    ../common/optional/v2raya.nix
    ../common/optional/waydroid.nix
    ../common/optional/proxychains.nix
  ];

  services.gnome.autoLogin = {
    enable = true;
    username = "lwa";
  };

  services.kmscon = {
    enable = true;
    autologinUser = "lwa";
    fonts = [
      {
        name = "MesloLGS NF";
        package = pkgs.meslo-lgs-nf;
      }
    ];
  };

  networking = {
    hostName = "asus";
  };

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

  hardware.graphics.enable = true;

  system.stateVersion = "24.11";
}
