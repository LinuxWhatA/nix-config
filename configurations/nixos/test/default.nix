# test 模块测试机
{ flake, ... }:
{
  imports = [
    ../redmi/grub.nix
    ./configuration.nix
    flake.config.nixosModules.base.nix
    flake.config.nixosModules.base.zsh
    flake.config.nixosModules.base.users
    flake.config.nixosModules.base.openssh
  ];

  home-manager.users.${flake.config.me.username}.imports = [
    flake.config.homeModules.cli.default
  ];
}
