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
  ];

  home-manager.users.${flake.config.me.username}.imports = [
    self.homeModules.default
    (self + /modules/home/cli/nh.nix)
    (self + /modules/home/cli/git.nix)
    (self + /modules/home/gui/opencode.nix)
  ];
}
