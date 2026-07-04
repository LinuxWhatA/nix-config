{ flake, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    self.homeModules.default
  ];

  home.username = "lwa";
  _module.args.hostname = "wsl";
  home.stateVersion = "26.11";
}
