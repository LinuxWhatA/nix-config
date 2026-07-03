{
  flake,
  pkgs,
  config,
  ...
}:

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
    # ISO 构建时使用 7.0 内核
    kernelPackages =
      if config.system.build ? isoImage then pkgs.linuxPackages_7_0 else pkgs.linuxPackages_zen;
    binfmt.emulatedSystems = [
      "aarch64-linux"
      "i686-linux"
    ];
    supportedFilesystems = [ "ntfs" ];
  };

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "redmi";
  system.stateVersion = "26.11";
}
