# test 为模块测试机，并非可部署主机
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

  # 特例：test 主机自定义用户模块（不随 home.nix 默认）
  home-manager.users.${flake.config.me.username}.imports = [
    self.homeModules.default
    (self + /modules/home/cli/nh.nix)
    (self + /modules/home/cli/git.nix)
    (self + /modules/home/cli/zsh.nix)
  ];
}
