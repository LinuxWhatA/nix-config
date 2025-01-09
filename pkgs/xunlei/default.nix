{
  lib,
  dpkg,
  stdenv,
  fetchurl,
  buildFHSEnv,
  autoPatchelfHook,
  writeShellScript,
  zenity,
  nss,
  gtk2,
  alsa-lib,
  dbus-glib,
  libXtst,
  libXdamage,
  libXScrnSaver,
}:

let
  xunlei = stdenv.mkDerivation rec {
    pname = "xunlei";
    version = "1.0.0.5";

    src =
      {
        x86_64-linux = fetchurl {
          url = "https://com-store-packages.uniontech.com/appstore/pool/appstore/c/com.xunlei.download/com.xunlei.download_${version}_amd64.deb";
          hash = "sha256-K+eHPmG2tT5Z+RWxigg03itw6Rcnk5MZlODqS/JtAnk=";
        };
        aarch64-linux = fetchurl {
          url = "https://com-store-packages.uniontech.com/appstore/pool/appstore/c/com.xunlei.download/com.xunlei.download_${version}_arm64.deb";
          hash = "sha256-iA9mbp0wSe66qC5lphMTFPzmOJjzHfWKubGRPiKcVdg=";
        };
      }
      .${stdenv.system} or (throw "${pname}-${version}: ${stdenv.system} is unsupported.");

    buildInputs = [
      nss
      gtk2
      alsa-lib
      dbus-glib
      libXtst
      libXdamage
      libXScrnSaver
    ];

    nativeBuildInputs = [
      dpkg
      autoPatchelfHook
    ];

    installPhase = ''
      mkdir -p $out/{lib,share}
      cp -r opt/apps/com.xunlei.download/files/* $out/lib
      cp -r opt/apps/com.xunlei.download/entries/* $out/share
      mv $out/share/icons/hicolor/scalable/apps/com.thunder.download.svg \
        $out/share/icons/hicolor/scalable/apps/com.xunlei.download.svg

      sed -e 's|^Exec=.*|Exec=${pname} %U --no-sandbox|' \
        -e 's|^Icon=.*|Icon=com.xunlei.download|' \
        -e 's|^Categories=.*|Categories=Network|' \
        -i $out/share/applications/com.xunlei.download.desktop

      install -Dm644 ${./LICENSE.html} $out/share/licenses/${pname}/LICENSE.html
    '';

    meta = with lib; {
      description = "xunlei download";
      homepage = "https://www.xunlei.com";
      license = licenses.unfree;
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    };
  };
in
buildFHSEnv {
  inherit (xunlei) pname version meta;
  runScript = writeShellScript "xunlei-launcher" ''
    exec ${xunlei}/lib/thunder -start $1 "$@"
  '';
  extraInstallCommands = ''
    mkdir -p $out
    ln -s ${xunlei}/share $out
  '';

  includeClosures = true;
  targetPkgs = pkgs: [ zenity ]; # system tray click events
}
