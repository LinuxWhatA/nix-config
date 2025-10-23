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
      substituteInPlace $out/usr/share/applications/@docmirrordev-sidecar-gui.desktop \
        --replace-fail "/opt/dev-sidecar/@docmirrordev-sidecar-gui" "dev-sidecar"
    '';
  };
in
buildFHSEnv {
  inherit (DevSidecar-unwrapped) pname version;
  runScript = writeShellScript "run-DevSidecar" ''
    exec ${DevSidecar-unwrapped}/opt/dev-sidecar/@docmirrordev-sidecar-gui "$@"
  '';
  extraInstallCommands = ''
    ln -s ${./dev-sidecar.ca.crt} $out/dev-sidecar.ca.crt
    ln -s ${./dev-sidecar.ca.key.pem} $out/dev-sidecar.ca.key.pem
    ln -s ${DevSidecar-unwrapped}/usr/share $out/share
  '';

  includeClosures = true;
  targetPkgs = pkgs: [
    nss
    glib
    gtk3
    mesa
    alsa-lib
  ];

  meta = {
    description = "Developer sidecar, proxy https requests to domestic accelerated channels";
    homepage = "https://github.com/docmirror/dev-sidecar";
    license = lib.licenses.mpl20;
    platforms = [ "x86_64-linux" ];
  };
}
