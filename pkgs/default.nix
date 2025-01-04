{
  pkgs ? import <nixpkgs> { },
  ...
}:

rec {
  fhs = pkgs.callPackage ./fhs { };
  winfonts = pkgs.callPackage ./winfonts { };
  proton-call = pkgs.callPackage ./proton-call { };
  patchedpython = pkgs.callPackage ./patchedpython { };
  plasma-applet-netspeed-widget = pkgs.callPackage ./plasma-applet-netspeed-widget { };

  xunlei = pkgs.callPackage ./xunlei { };
}
