# test 模块测试机
{ flake, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    ../redmi/grub.nix
    ./configuration.nix
    (self + /modules/nixos/base/nix.nix)
    (self + /modules/nixos/base/zsh.nix)
    (self + /modules/nixos/base/users.nix)
    (self + /modules/nixos/base/openssh.nix)
  ];

  home-manager.users.${flake.config.me.username}.imports = [
    self.homeModules.default
    (self + /modules/home/cli/nh.nix)
    (self + /modules/home/cli/git.nix)
  ];
}
