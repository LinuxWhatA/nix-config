{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  users.mutableUsers = true;

  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    kernelParams = [
      # FIXME: amdgpu 7.0.13+ 内核回归（Rembrandt APU gfx ring timeout）缓解，
      "amdgpu.cwsr_enable=0"
    ];
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
