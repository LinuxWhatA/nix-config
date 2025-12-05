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
    (self + /modules/nixos/common/nix.nix)
    (self + /modules/nixos/common/vim.nix)
    (self + /modules/nixos/common/packages.nix)
  ];

  users.users.lwa = {
    openssh.authorizedKeys.keys = [ flake.config.me.sshKey ];
  };
}
