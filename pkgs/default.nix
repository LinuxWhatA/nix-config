{
  pkgs ? import <nixpkgs> { },
  ...
}:

rec {
  fhs = pkgs.callPackage ./fhs { };
  winfonts = pkgs.callPackage ./winfonts { };
  proton-call = pkgs.callPackage ./proton-call { };
  patchedpython = pkgs.callPackage ./patchedpython { };

  xunlei = pkgs.callPackage ./xunlei { };
}
