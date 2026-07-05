# See /modules/nixos/* for actual settings
# This file is just *top-level* configuration.
{ flake, pkgs, lib, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    ./configuration.nix
    inputs.nixos-wsl.nixosModules.wsl
    self.nixosModules.default
  ];
}
