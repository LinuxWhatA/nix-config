{ pkgs, lib, ... }:

{
  # 注：envfs 是独立的 /usr/bin 兜底（shebang 硬编码）方案，与 nix-ld 作用不同，
  # 不要把它误当作 nix-ld 的替代/继承者而合并。
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
    ];
  };

  services.envfs.enable = lib.mkDefault true;
}
