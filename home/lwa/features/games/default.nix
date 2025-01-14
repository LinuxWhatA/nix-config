{ pkgs, ... }:

{
  imports = [
    ./mangohud.nix
  ];

  home.packages = with pkgs; [
    (callPackage ./epicgames { })
  ];
}
