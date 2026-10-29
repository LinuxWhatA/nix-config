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

  # 交换与内存额度由 Windows 的 .wslconfig 管，guest 再开 zram 只是和宿主争内存
  zramSwap.enable = false;

  # 生成 nixos.wsl
  # sudo nix run '.#nixosConfigurations.wsl.config.system.build.tarballBuilder'
}
