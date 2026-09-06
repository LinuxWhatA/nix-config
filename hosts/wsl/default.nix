# wsl 主机
{ flake, ... }:
let
  inherit (flake) inputs;
in
{
  imports = [
    ./configuration.nix
    inputs.nixos-wsl.nixosModules.wsl
    flake.config.nixosModules.base.default
    flake.config.nixosModules.gui.clash
  ];

  home-manager.users.${flake.config.me.username}.imports = [
    flake.config.homeModules.cli.default
    flake.config.homeModules.gui.opencode
  ];
}
