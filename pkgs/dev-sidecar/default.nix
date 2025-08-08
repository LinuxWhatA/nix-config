{
  lib,
  openssl,
  fetchurl,
  appimageTools,
}:

let
  pname = "dev-sidecar";
  version = "2.0.0.2";

  src = fetchurl {
    url = "https://github.com/docmirror/dev-sidecar/releases/download/v${version}/DevSidecar-${version}-linux-x86_64.AppImage";
    hash = "sha256-bEGXlm0VFVPU/FZ2ACBVIKoBxGKVQZ4lDa8ue6I22xs=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit src pname version;

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/@docmirrordev-sidecar-gui.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/@docmirrordev-sidecar-gui.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=dev-sidecar'
    cp -r ${appimageContents}/usr/share/icons $out/share
    ${openssl}/bin/openssl genrsa -out $out/dev-sidecar.ca.key.pem 2048
    ${openssl}/bin/openssl req -x509 -new -nodes -key $out/dev-sidecar.ca.key.pem -sha256 -days 3650 \
      -out $out/dev-sidecar.ca.crt -subj ""/C=CN/ST=GuangDong/L=ShenZhen/O=dev-sidecar/CN=DevSidecar""
  '';

  meta = {
    description = "Developer sidecar, proxy https requests to domestic accelerated channels";
    homepage = "https://github.com/docmirror/dev-sidecar";
    license = lib.licenses.mpl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "dev-sidecar";
  };
}
