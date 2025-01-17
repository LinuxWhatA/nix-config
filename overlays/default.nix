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
    # Dynamic triple buffering
    # You might need to disable aliases to make it work
    # nixpkgs.config.allowAliases = false;
    # GNOME 46: triple-buffering-v4-46
    gnome = prev.gnome.overrideScope (
      gnomeFinal: gnomePrev: {
        mutter = gnomePrev.mutter.overrideAttrs (old: {
          src = old.fetchFromGitLab {
            domain = "gitlab.gnome.org";
            owner = "vanvugt";
            repo = "mutter";
            rev = "triple-buffering-v4-46";
            hash = "sha256-C2VfW3ThPEZ37YkX7ejlyumLnWa9oij333d5c4yfZxc=";
          };
        });
      }
    );

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
        repo = "proton-caller";
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

    # lutris 添加 winetricks
    lutris = prev.lutris.override {
      extraPkgs =
        pkgs: with pkgs; [
          winetricks
        ];
    };
  };
}
