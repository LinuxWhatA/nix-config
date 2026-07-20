{ flake, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    self.nixosModules.default
    (self + /modules/nixos/gui/gnome.nix)
    ./configuration.nix
  ];
}
