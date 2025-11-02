{
  lib,
  pkgs,
  config,
  outputs,
  ...
}:

{
  imports = [
    ../features/cli
  ] ++ (builtins.attrValues outputs.homeManagerModules);

  systemd.user.startServices = "sd-switch";

  programs = {
    home-manager.enable = true;
    git.enable = true;
  };

  home = {
    username = lib.mkDefault "lwa";
    homeDirectory = lib.mkDefault "/home/${config.home.username}";
    stateVersion = lib.mkDefault "25.11";
  };

  xdg.userDirs.enable = true;
  xdg.userDirs.createDirectories = true;
}
