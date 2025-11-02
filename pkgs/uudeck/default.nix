{ stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "uudeck";
  version = "0-unstable-2025-04-12";

  src = ./.;
  installPhase = ''
    install -Dm755 uuplugin_monitor.sh $out/bin/uudeck
  '';
}
