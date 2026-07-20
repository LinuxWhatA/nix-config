{ flake, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    ./configuration.nix
    self.nixosModules.default
    inputs.nixos-wsl.nixosModules.wsl
    (self + /modules/nixos/cli/nix.nix)
  ];
}
