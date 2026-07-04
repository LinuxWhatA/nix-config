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
  _module.args.hostname = "asus";
  home.stateVersion = "25.11";
}
