{ flake, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    ../redmi/grub.nix
    ./configuration.nix

    (self + /modules/nixos/base)
  ];

  # 特例：test 主机自定义用户模块（不随 home.nix 默认）
  home-manager.users.lwa.imports = [
    (self + /modules/home/cli/nh.nix)
    (self + /modules/home/cli/git.nix)
    (self + /modules/home/cli/zsh.nix)
  ];
}
