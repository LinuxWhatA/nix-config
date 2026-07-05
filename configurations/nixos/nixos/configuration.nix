{
  flake,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
  ];

  users.mutableUsers = true;

  boot = {
    # ISO 构建时使用 7.0 内核
    kernelPackages = pkgs.linuxPackages_7_0;
    supportedFilesystems = [ "ntfs" ];
  };

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "nixos";
  system.stateVersion = "26.11";
}
