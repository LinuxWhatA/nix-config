{
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    (modulesPath + "/installer/cd-dvd/channel.nix")
  ];

  environment.systemPackages = with pkgs; [
    jq # disko required
    disko
  ];

  # 快速压缩
  isoImage.squashfsCompression = "lz4";

  boot.loader.grub.enable = lib.mkForce false;
}
