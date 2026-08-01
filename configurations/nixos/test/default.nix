{ flake, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    (self + /modules/nixos/cli/nix.nix)
    (self + /modules/nixos/cli/home.nix)
    ../redmi/grub.nix
    ./configuration.nix
  ];
}
