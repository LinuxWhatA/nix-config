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

    ./hardware-configuration.nix

    ../common/global
    ../common/users/lwa

    ../common/optional/kde.nix
    ../common/optional/swap.nix
    ../common/optional/pipewire.nix
    ../common/optional/quietboot.nix

    ../common/optional/hosts.nix
    ../common/optional/steam.nix
    ../common/optional/v2raya.nix
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
    loader = {
      efi.canTouchEfiVariables = true;
      grub = {
        enable = true;
        efiSupport = true;
        device = "nodev";
        default = "saved";
        useOSProber = true;
        configurationLimit = 10;
        extraFiles = {
          "ntloader" = "${pkgs.ntloader}/ntloader";
          "initrd.cpio" = "${pkgs.ntloader}/initrd.cpio";
        };
        extraEntries = ''
          menuentry "Windows VHD" --class windows {
            savedefault
            search --set=root --fs-uuid 12CE-A600
            chainloader /ntloader initrd=/initrd.cpio uuid=F604474D04470FD3 file=/OS/Windows.vhd
          }

          menuentry "Ventoy" {
            savedefault
            search --set=root --fs-uuid 223C-F3F8
            chainloader /EFI/BOOT/grubx64_real.efi
          }
        '';
      };
    };
  };

  programs = {
    adb.enable = true;
  };

  environment.systemPackages = with pkgs; [
    easyeffects # 用于反转左右声道
  ];

  hardware.graphics.enable = true;

  system.stateVersion = "24.11";
}
