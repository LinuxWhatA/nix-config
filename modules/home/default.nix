{ flake, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    # inputs.nix-index-database.homeModules.nix-index
    self.homeModules.common
  ];

  xdg.userDirs.enable = true;
  xdg.userDirs.createDirectories = true;
  xdg.userDirs.setSessionVariables = false;

  home.stateVersion = "25.11";
}
