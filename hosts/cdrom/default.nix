{
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-graphical-base.nix")
    (modulesPath + "/installer/cd-dvd/channel.nix")
  ];

  users.users.lwa = {
    password = lib.mkForce "";
    hashedPasswordFile = lib.mkForce null;
  };

  environment.systemPackages = with pkgs; [
    jq # disko required
    disko
  ];

  # 快速压缩
  isoImage.squashfsCompression = "gzip -Xcompression-level 1";

  boot.loader.grub.enable = lib.mkForce false;
}
