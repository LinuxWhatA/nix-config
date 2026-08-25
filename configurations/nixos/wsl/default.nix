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
    (self + /modules/nixos/gui/clash.nix)
  ];

  home-manager.users.${flake.config.me.username}.imports = [
    self.homeModules.cli
    (self + /modules/home/gui/opencode.nix)
    (self + /modules/home/gui/deepseek.nix)
  ];
}
