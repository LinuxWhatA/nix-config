# naix 主机 —— 组合清单
# 规则：需要什么才导入什么，一行一个文件
#   全部文件按分类存放，无自动接线 → 一律 (self + /modules/nixos/<分类>/<文件>.nix)
#   新增功能 = 分类目录内新建文件 + 本文件加一行
{ flake, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    # 硬件（nixos-hardware）
    inputs.hardware.nixosModules.common-pc
    inputs.hardware.nixosModules.common-pc-ssd
    inputs.hardware.nixosModules.common-gpu-amd
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-cpu-amd-pstate
    inputs.hardware.nixosModules.common-cpu-amd-zenpower

    # 基础（逐项导入，主机按需取舍）
    (self + /modules/nixos/services/home.nix)
    (self + /modules/nixos/cli/nix.nix)
    (self + /modules/nixos/desktop/locale.nix)
    (self + /modules/nixos/services/networking.nix)
    (self + /modules/nixos/services/security.nix)
    (self + /modules/nixos/hardware/swap.nix)
    (self + /modules/nixos/desktop/getty.nix)
    (self + /modules/nixos/hardware/persist.nix)

    # 桌面环境（desktop/，互斥，只导入所需）
    (self + /modules/nixos/desktop/gnome.nix)

    # 虚拟化（virtualization/）
    (self + /modules/nixos/virtualization/qemu.nix)
    (self + /modules/nixos/virtualization/waydroid.nix)

    # 主机定制
    ./grub.nix
    ./configuration.nix
  ];

  # 系统内 home-manager 按需注入用户模块（gui 由 DE 模块自带注入）
  home-manager.users.lwa.imports = [
    self.homeModules.default
    self.homeModules.cli
  ];
}
