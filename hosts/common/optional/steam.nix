{ pkgs, ... }:

{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = false;
    dedicatedServer.openFirewall = false;

    extraCompatPackages = [ pkgs.proton-ge-bin ];
    package = pkgs.steam.override {
      extraPkgs =
        pkgs': with pkgs'; [
          # https://wiki.nixos.org/wiki/Steam/zh
          xorg.libXcursor
          xorg.libXi
          xorg.libXinerama
          xorg.libXScrnSaver
          libpng
          libpulseaudio
          libvorbis
          stdenv.cc.cc.lib # Provides libstdc++.so.6
          libkrb5
          keyutils
          # https://wiki.nixos.org/wiki/Games
          libxkbcommon
          mesa
          wayland
          (sndio.overrideAttrs (old: {
            postFixup = ''
              ln -s $out/lib/libsndio.so $out/lib/libsndio.so.6.1
            '';
          }))
        ];
    };
  };

  programs.gamescope.enable = true;
  programs.gamemode.enable = true;
  hardware.steam-hardware.enable = true;
}
