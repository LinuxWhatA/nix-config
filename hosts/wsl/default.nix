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
    flake.config.nixosModules.gui.thunar
  ];

  home-manager.users.${flake.config.me.username}.imports = [
    flake.config.homeModules.cli.default
  ];

  # 生成 nixos.wsl
  # sudo nix run '.#nixosConfigurations.wsl.config.system.build.tarballBuilder'
}
