# test 模块测试机
{ flake, ... }:
{
  imports = [
    # 公共 grub 已覆盖本箱想验证的 boot/loader 求值面；redmi 专属 GRUB 差异
    # （a1ive 编译链、Windows/PE 启动项）不该经主机互相引用进测试箱
    flake.config.nixosModules.hardware.grub
    ./configuration.nix
    flake.config.nixosModules.base.host
    flake.config.nixosModules.base.nix
    flake.config.nixosModules.base.zsh
    flake.config.nixosModules.base.users
    flake.config.nixosModules.base.openssh
  ];

  home-manager.users.${flake.config.me.username}.imports = [
    flake.config.homeModules.cli.default
  ];
}
