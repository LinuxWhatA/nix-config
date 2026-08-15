{ pkgs, lib, ... }:

{
  fonts = {
    # mkForce 保持开启（防御性）：
    # nixpkgs build-image 变体 iso/iso-installer 分别来自 iso-image.nix /
    # installation-cd-base.nix，实测均不含 fontconfig 覆盖，ISO 中本就是 true。
    # 但若有人显式合并官方安装盘配置（installation-cd-minimal.nix，其内部为
    #   fonts.fontconfig.enable = lib.mkOverride 500 false;
    # 优先级 500 > 普通赋值 100，会把字体关掉），mkForce(50) 是唯一能顶住的手段。
    # 来源：nixpkgs nixos/modules/installer/cd-dvd/installation-cd-minimal.nix
    fontconfig.enable = lib.mkForce true;
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      meslo-lgs-nf
      dejavu_fonts
      nerd-fonts.fira-code
      winfonts
    ];

    fontconfig.defaultFonts = {
      serif = [
        "DejaVu Serif"
        "Microsoft YaHei"
      ];
      sansSerif = [
        "DejaVu Sans"
        "Microsoft YaHei"
      ];
      monospace = [
        "DejaVu Sans Mono"
        "FiraCode Nerd Font Mono"
      ];
    };
  };
}
