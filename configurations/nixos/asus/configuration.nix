{ flake, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  users.mutableUsers = true;
  users.users.lwa = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];

    openssh.authorizedKeys.keys = [ flake.config.me.sshKey ];
    hashedPassword = "$6$6aT0cza7dVGIOdsf$ICgv1WOo255hp41vzsz2c7m1BtI51MFfmR7K7qJdJ4zRR2yFSNS0mKsqSMhMPPSWbShpi5UzgMmOkd/9UMxEg0";
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    binfmt.emulatedSystems = [
      "aarch64-linux"
      "i686-linux"
    ];
  };

  boot.loader = {
    systemd-boot = {
      enable = true;
      consoleMode = "max";
    };
    efi.canTouchEfiVariables = true;
  };

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "asus";
  system.stateVersion = "25.11";
}
