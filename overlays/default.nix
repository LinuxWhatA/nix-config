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
    # wechat-uos 添加 Network 分类
    wechat-uos = prev.buildFHSEnv (
      prev.wechat-uos.args
      // {
        extraInstallCommands =
          prev.wechat-uos.args.extraInstallCommands
          + ''
            sed -i 's|^Categories=.*|Categories=Network;Chat;|' \
              $out/share/applications/com.tencent.wechat.desktop
          '';
      }
    );

    # proton-caller 换源
    proton-caller = prev.proton-caller.overrideAttrs (old: {
      src = old.src.override {
        owner = "LinuxWhatA";
        rev = "7ed1962baf920893368f805dc63c896a2f206176";
        sha256 = "sha256-gAnsP4AR1NnTCThF29H3qvI+PP459qYX72+OBHX0kV4=";
      };
      cargoHash = "sha256-LBXCcFqqscCGgtTzt/gr7Lz0ExT9kAWrXPuPuKzKt0E=";
    });

    # https://wiki.nixos.org/wiki/Games
    steam-run =
      (prev.steam.override {
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
      }).run;

    # update winetricks
    winetricks = prev.winetricks.overrideAttrs (old: {
      src = old.src.override rec {
        version = "20250102";
        hash = "sha256-Km2vVTYsLs091cjmNTW8Kqku3vdsEA0imTtZfqZWDQo=";
        rev = version;
      };
    });
  };
}
