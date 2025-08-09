{
  lib,
  dpkg,
  stdenv,
  openssl,
  fetchurl,
  buildFHSEnv,
  writeShellScript,
  nss,
  gtk3,
  mesa,
  alsa-lib,
}:

let
  DevSidecar-unwrapped = stdenv.mkDerivation rec {
    pname = "dev-sidecar";
    version = "2.0.0.2";

    src = fetchurl {
      url = "https://github.com/docmirror/dev-sidecar/releases/download/v${version}/DevSidecar-${version}-linux-amd64.deb";
      hash = "sha256-QxZy6yRAt59akgAMj3oM8Bmd8k+0ccz0587ed4nGZ5g=";
    };

    nativeBuildInputs = [ dpkg ];
    unpackPhase = "dpkg-deb -x $src $out";

    installPhase = ''
      sed -i 's|^Exec=.*|Exec=dev-sidecar %U|' \
        $out/usr/share/applications/@docmirrordev-sidecar-gui.desktop
    '';
  };
in
buildFHSEnv {
  inherit (DevSidecar-unwrapped) pname version;
  runScript = writeShellScript "dev-sidecar" ''
    exec ${DevSidecar-unwrapped}/opt/dev-sidecar/@docmirrordev-sidecar-gui "$@"
  '';
  extraInstallCommands = ''
    ${openssl}/bin/openssl genrsa -out $out/dev-sidecar.ca.key.pem 2048
    ${openssl}/bin/openssl req -x509 -new -nodes -key $out/dev-sidecar.ca.key.pem -sha256 -days 365 \
      -out $out/dev-sidecar.ca.crt -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=dev-sidecar/CN=DevSidecar"

    ln -s ${DevSidecar-unwrapped}/usr/share $out/share
  '';

  includeClosures = true;
  targetPkgs = pkgs: [
    nss
    gtk3
    mesa
    alsa-lib
  ];

  meta = {
    description = "Developer sidecar, proxy https requests to domestic accelerated channels";
    homepage = "https://github.com/docmirror/dev-sidecar";
    license = lib.licenses.mpl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "dev-sidecar";
  };
}
