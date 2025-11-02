{
  pkgs ? import <nixpkgs> { },
  ...
}:

{
  fhs = pkgs.callPackage ./fhs { };
  uudeck = pkgs.callPackage ./uudeck { };
  winfonts = pkgs.callPackage ./winfonts { };
  ntloader = pkgs.callPackage ./ntloader { };
  proton-run = pkgs.callPackage ./proton-run { };
  patchedpython = pkgs.callPackage ./patchedpython { };
  fcitx-sogoupinyin = pkgs.callPackage ./fcitx-sogoupinyin { };
  grub-cyberre-theme = pkgs.callPackage ./grub-cyberre-theme { };
  plymouth-550w-theme = pkgs.callPackage ./plymouth-550w-theme { };
  plasma-applet-netspeed-widget = pkgs.callPackage ./plasma-applet-netspeed-widget { };

  dev-sidecar = pkgs.callPackage ./dev-sidecar { };
  unblock-netease-music = pkgs.callPackage ./unblock-netease-music { };
}
