{
  appimageTools,
  fetchurl,
  lib,
}:
let
  pname = "tracedraw";
  version = "0.45.1";

  src = fetchurl {
    url = "https://github.com/tracedraw/tracedraw/releases/download/v${version}/tracedraw-${version}-linux-amd64.AppImage";
    hash = "sha256-bbhjff78oos8j2/WxtPnyfjsQqULtVEyLFtd7KI4wko=";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;
  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/tracedraw.desktop \
      $out/share/applications/tracedraw.desktop

    cp -r --no-preserve=mode ${appimageContents}/usr/share/icons $out/share
  '';

  meta = {
    description = "TraceDraw - vector illustration editor";
    homepage = "https://github.com/tracedraw/tracedraw";
    changelog = "https://github.com/tracedraw/tracedraw/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "tracedraw";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
