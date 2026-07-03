{ flake, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    self.homeModules.gui
    self.homeModules.default
  ];

  home.username = "lwa";
  home.stateVersion = "26.11";
}
