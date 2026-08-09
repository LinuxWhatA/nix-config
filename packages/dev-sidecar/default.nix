{
  lib,
  dpkg,
  stdenv,
  fetchurl,
  buildFHSEnv,
  writeShellScript,
  nss,
  glib,
  gtk3,
  mesa,
  openssl,
  alsa-lib,
}:

let
  dev-sidecar-unwrapped = stdenv.mkDerivation rec {
    pname = "dev-sidecar";
    version = "2.2.0";

    src = fetchurl {
      url = "https://github.com/docmirror/dev-sidecar/releases/download/v${version}/DevSidecar-${version}-linux-x86_64.deb";
      hash = "sha256-zsWIoTdvOEmh+1L2VoHcOEcOuw9ZaUVxpPZAX/Vl3cE=";
    };

    nativeBuildInputs = [
      dpkg
      openssl
    ];
    unpackPhase = "dpkg-deb -x $src $out";

    installPhase = ''
      substituteInPlace $out/usr/share/applications/@docmirrordev-sidecar-gui.desktop \
        --replace-fail "/opt/dev-sidecar/@docmirrordev-sidecar-gui" "dev-sidecar"
      # CA certificate
      cd $out
      bash ${./generate-cert.sh}
    '';
  };
in
buildFHSEnv {
  inherit (dev-sidecar-unwrapped) pname version;
  runScript = writeShellScript "run-DevSidecar" ''
    exec ${dev-sidecar-unwrapped}/opt/dev-sidecar/@docmirrordev-sidecar-gui "$@"
  '';
  extraInstallCommands = ''
    ln -s ${dev-sidecar-unwrapped}/dev-sidecar.ca.crt $out/dev-sidecar.ca.crt
    ln -s ${dev-sidecar-unwrapped}/dev-sidecar.ca.key.pem $out/dev-sidecar.ca.key.pem
    ln -s ${dev-sidecar-unwrapped}/usr/share $out/share
  '';

  includeClosures = true;
  targetPkgs = pkgs: [
    nss
    glib
    gtk3
    mesa
    openssl
    alsa-lib
  ];

  meta = {
    description = "Developer sidecar, proxy https requests to domestic accelerated channels";
    homepage = "https://github.com/docmirror/dev-sidecar";
    license = lib.licenses.mpl20;
    platforms = [ "x86_64-linux" ];
  };
}
