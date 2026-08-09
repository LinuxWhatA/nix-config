{ pkgs, lib, ... }:

{
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
    ];
  };

  services.envfs.enable = lib.mkForce true;
}
