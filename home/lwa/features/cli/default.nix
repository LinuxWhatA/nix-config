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
    proton-call
    patchedpython
    nixfmt-rfc-style
  ];
}
