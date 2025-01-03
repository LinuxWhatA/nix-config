{
  lib,
  dpkg,
  stdenv,
  fetchurl,
  steam-run,
  makeWrapper,
  autoPatchelfHook,
  writeShellScript,
  nss,
  gtk2,
  alsa-lib,
  dbus-glib,
  libXtst,
  libXdamage,
  libXScrnSaver,
}:

stdenv.mkDerivation rec {
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
        hash = "";
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
    makeWrapper
    autoPatchelfHook
  ];

  dontConfigure = true;
  dontBuild = true;

  xunlei = writeShellScript "xunlei" ''
    _APPDIR=$(realpath $(dirname $(realpath $0))/..)
    export LD_LIBRARY_PATH=$_APPDIR/lib:$LD_LIBRARY_PATH
    ${steam-run}/bin/steam-run $_APPDIR/lib/thunder -start $1 "$@"
  '';

  installPhase = ''
    mkdir -p $out/{bin,lib,share}
    cp -Pr --no-preserve=ownership opt/apps/com.xunlei.download/files/* $out/lib
    cp -r opt/apps/com.xunlei.download/entries/* $out/share
    mv $out/share/icons/hicolor/scalable/apps/com.thunder.download.svg \
      $out/share/icons/hicolor/scalable/apps/com.xunlei.download.svg

    sed -i -e 's|^Exec=.*|Exec=${pname} %U --no-sandbox|' \
      -e 's|^Icon=.*|Icon=com.xunlei.download|' \
      -e 's|^Categories=.*|Categories=Network|' \
      $out/share/applications/com.xunlei.download.desktop

    install -Dm755 ${xunlei} $out/bin/${pname}
    install -Dm644 ${./license.html} -t $out/share/licenses/${pname}
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
}
