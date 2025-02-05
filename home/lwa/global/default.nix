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

  nix = {
    package = lib.mkDefault pkgs.nix;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;
    };
  };

  systemd.user.startServices = "sd-switch";

  programs = {
    home-manager.enable = true;
    git.enable = true;
  };

  home = {
    username = lib.mkDefault "lwa";
    homeDirectory = lib.mkDefault "/home/${config.home.username}";
    stateVersion = lib.mkDefault "24.11";
  };

  xdg.userDirs.enable = true;
  xdg.userDirs.createDirectories = true;
}
