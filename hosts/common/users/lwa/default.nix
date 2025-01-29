{
  pkgs,
  config,
  lib,
  ...
}:

let
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  users.mutableUsers = true;
  users.users.lwa = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = ifTheyExist [
      "git"
      "wheel"
      "audio"
      "video"
      "network"
      "libvirtd"
      "adbusers"
    ];

    hashedPasswordFile = config.sops.secrets.lwa-password.path;
    packages = [ pkgs.home-manager ];
  };

  sops.secrets.lwa-password = {
    sopsFile = ../../secrets.yaml;
    neededForUsers = true;
  };

  home-manager.users.lwa = import ../../../../home/lwa/${config.networking.hostName}.nix;
  home-manager.users.root = import ../../../../home/root;
}
