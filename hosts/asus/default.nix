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

    ../common/optional/kde.nix
    ../common/optional/swap.nix
    ../common/optional/wireless.nix
    ../common/optional/pipewire.nix
    ../common/optional/plymouth.nix
    ../common/optional/systemd-boot.nix

    ../common/optional/hosts.nix
    ../common/optional/steam.nix
    ../common/optional/v2raya.nix
    ../common/optional/proxychains.nix
  ];

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "lwa";

  services.xrdp = {
    enable = true;
    openFirewall = true;
    defaultWindowManager = ''
      unset DBUS_SESSION_BUS_ADDRESS
      unset XDG_RUNTIME_DIR
      startplasma-x11
    '';
  };

  # FIXME 开启此选项无法进入桌面
  # my.kmscon.enable = true;
  # my.kmscon.autologinUser = "lwa";

  networking.hostName = "asus";

  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_zen;
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
  };

  system.stateVersion = "24.11";
}
