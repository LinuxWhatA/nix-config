# 跨平台 CLI 工具
{ flake, pkgs, ... }:

{
  imports = [
    flake.inputs.nix-index-database.homeModules.nix-index
  ];

  home.packages = with pkgs; [
    # Unix tools
    yq # YAML
    sd # sed
    less
    rar
    duf # du
    htop
    snitch # 网络监控
    usbutils
    pciutils
    vulkan-tools

    # Nix dev
    nixd
    nixfmt
    statix
    nix-info
    nix-alien

    # Custom Program
    fhs
    cdrtools
    python3
    cgroupRun
  ];

  programs = {
    fzf.enable = true;
    jq.enable = true;
    btop.enable = true;
    ripgrep.enable = true;
    fastfetch.enable = true;
    opencode.enable = true;
    nix-index-database.comma.enable = true;
  };
}
