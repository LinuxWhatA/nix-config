{
  appimageTools,
  fetchurl,
  lib,
}:
let
  pname = "dsh-desktop-next";
  version = "2.0.20";

  src = fetchurl {
    url = "https://github.com/anywhere-labs/dsh-desktop/releases/download/v${version}-next/DSH-NEXT-${version}-next-x86_64.AppImage";
    hash = "sha256-YfJLVvVVX2Pd/dP5XO3bGdLdA16/PaDHfb8dBxa0Ceg=";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs = pkgs: [ ];

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/dsh-desktop-next.desktop \
      $out/share/applications/dsh-desktop-next.desktop
    substituteInPlace $out/share/applications/dsh-desktop-next.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=dsh-desktop-next'

    cp -r --no-preserve=mode ${appimageContents}/usr/share/icons $out/share
    install -dm755 "$out/share/icons/hicolor/512x512/apps"
    ln -sf ../../1024x1024/apps/dsh-desktop-next.png \
      "$out/share/icons/hicolor/512x512/apps/dsh-desktop-next.png"
  '';

  meta = {
    description = "An open-source desktop client, built on DeepSeek Harness";
    homepage = "https://github.com/anywhere-labs/dsh-desktop";
    changelog = "https://github.com/anywhere-labs/dsh-desktop/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "dsh-desktop-next";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
