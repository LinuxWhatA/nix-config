{ pkgs, ... }:

{
  imports = [
    ./git.nix
  ];

  home.packages = with pkgs; [
    fhs
    rar
    htop
    fastfetch
    proton-run
    patchedpython
    nixfmt-rfc-style
  ];
}
