{
  lib,
  pkgs,
  inputs,
  config,
  ...
}:

let
  aurPatches = pkgs.fetchgit {
    url = "https://aur.archlinux.org/nvidia-470xx-utils.git";
    rev = "7c1c2c124147d960a6c7114eb26a4eadae9b9f3d";
    hash = "sha256-sNW+I4dkPSudfORLEp1RNGHyQKWBYnBEeGrfJU7SYTs=";
  };
in
{
  imports = [
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.hardware.nixosModules.common-gpu-nvidia
    inputs.hardware.nixosModules.common-pc-laptop
    inputs.hardware.nixosModules.common-pc-laptop-ssd

    ./hardware-configuration.nix

    ../common/global
    ../common/users/lwa

    ../common/optional/kde.nix
    ../common/optional/swap.nix
    ../common/optional/uudeck.nix
    ../common/optional/nix-ld.nix
    ../common/optional/wireless.nix
    ../common/optional/pipewire.nix
    ../common/optional/plymouth.nix
    ../common/optional/systemd-boot.nix

    ../common/optional/hosts.nix
    ../common/optional/steam.nix
    ../common/optional/v2raya.nix
    ../common/optional/sunshine.nix
    ../common/optional/proxychains.nix
  ];

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "lwa";

  my.kmscon.enable = true;
  my.kmscon.autologinUser = "lwa";

  networking.hostName = "asus";

  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    binfmt.emulatedSystems = [
      "aarch64-linux"
      "i686-linux"
    ];
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];
  nixpkgs.config.nvidia.acceptLicense = true;

  hardware.nvidia = {
    open = false;
    package = config.boot.kernelPackages.nvidia_x11_legacy470.overrideAttrs (old: {
      patches = map (patch: "${aurPatches}/${patch}") [
        "0001-Fix-conftest-to-ignore-implicit-function-declaration.patch"
        "0002-Fix-conftest-to-use-a-short-wchar_t.patch"
        "0003-Fix-conftest-to-use-nv_drm_gem_vmap-which-has-the-se.patch"
        "nvidia-470xx-fix-gcc-15.patch"
        "kernel-6.10.patch"
        "kernel-6.12.patch"
        "nvidia-470xx-fix-linux-6.13.patch"
        "nvidia-470xx-fix-linux-6.14.patch"
        "nvidia-470xx-fix-linux-6.15.patch"
        "nvidia-470xx-fix-linux-6.17.patch"
      ];
      patchFlags = [
        "-p1"
        "--directory=kernel"
      ];
    });
    nvidiaSettings = true;
    modesetting.enable = true;
    powerManagement.enable = true;

    prime = {
      sync.enable = true;
      offload = {
        enable = false;
        enableOffloadCmd = false;
      };
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:4:0:0";
    };
  };

  specialisation.on-the-go.configuration = {
    system.nixos.tags = [ "on-the-go" ];
    hardware.nvidia.prime = {
      sync.enable = lib.mkForce false;
      offload.enable = lib.mkForce true;
      offload.enableOffloadCmd = lib.mkForce true;
    };
  };

  system.stateVersion = "25.11";
}
