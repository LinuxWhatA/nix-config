{
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  isoImage = {
    makeEfiBootable = true;
    makeBiosBootable = true;
  };

  services.resolved.enable = true;
  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
