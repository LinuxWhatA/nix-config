{
  pkgs,
  config,
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
      "wheel"
      "audio"
      "video"
      "input"
      "libvirtd"
      "adbusers"
      "networkmanager"
    ];

    hashedPassword = "$6$6aT0cza7dVGIOdsf$ICgv1WOo255hp41vzsz2c7m1BtI51MFfmR7K7qJdJ4zRR2yFSNS0mKsqSMhMPPSWbShpi5UzgMmOkd/9UMxEg0";
    packages = [ pkgs.home-manager ];
  };

  home-manager.users.lwa = import ../../../../home/lwa/${config.networking.hostName}.nix;
  home-manager.users.root = import ../../../../home/root;
}
