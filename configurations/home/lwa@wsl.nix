{ flake, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    (self + /modules/home/common/git.nix)
    (self + /modules/home/common/zsh.nix)
  ];

  home.username = "lwa";
  home.stateVersion = "25.05";
}
