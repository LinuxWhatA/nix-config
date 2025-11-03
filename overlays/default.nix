{
  outputs,
  inputs,
}:

let
  addPatches =
    pkg: patches:
    pkg.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or [ ]) ++ patches;
    });
in
{
  # Adds my custom packages
  additions = final: prev: import ../pkgs { pkgs = final; };

  # Modifies existing packages
  modifications = final: prev: {
    # wechat
    wechat = prev.wechat.overrideAttrs (old: {
      src = prev.fetchurl {
        url = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage";
        hash = "sha256-gBWcNQ1o1AZfNsmu1Vi1Kilqv3YbR+wqOod4XYAeVKo=";
      };
    });

    # proton-caller 换源
    proton-caller = prev.proton-caller.overrideAttrs (old: {
      src = old.src.override {
        owner = "LinuxWhatA";
        rev = "7ed1962baf920893368f805dc63c896a2f206176";
        sha256 = "sha256-gAnsP4AR1NnTCThF29H3qvI+PP459qYX72+OBHX0kV4=";
      };
      cargoHash = "sha256-LBXCcFqqscCGgtTzt/gr7Lz0ExT9kAWrXPuPuKzKt0E=";
    });

    steam = prev.steam.override {
      extraPkgs =
        pkgs': with pkgs'; [
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
        ];
      # https://wiki.nixos.org/wiki/Games
      extraLibraries =
        pkgs: with pkgs; [
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
}
