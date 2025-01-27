{
  pkgs ? import <nixpkgs> { },
  ...
}:

rec {
  fhs = pkgs.callPackage ./fhs { };
  winfonts = pkgs.callPackage ./winfonts { };
  ntloader = pkgs.callPackage ./ntloader { };
  proton-run = pkgs.callPackage ./proton-run { };
  patchedpython = pkgs.callPackage ./patchedpython { };
  plasma-applet-netspeed-widget = pkgs.callPackage ./plasma-applet-netspeed-widget { };

  xunlei-uos = pkgs.callPackage ./xunlei-uos { };
  dev-sidecar = pkgs.callPackage ./dev-sidecar { };
  unblock-netease-music = pkgs.callPackage ./unblock-netease-music { };
}
