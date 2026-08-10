# wsl 主机
{ flake, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    ./configuration.nix
    inputs.nixos-wsl.nixosModules.wsl
    (self + /modules/nixos/base)
    (self + /modules/nixos/services/pipewire.nix)
  ];

  home-manager.users.${flake.config.me.username}.imports = [
    self.homeModules.default
    self.homeModules.cli
  ];
}
