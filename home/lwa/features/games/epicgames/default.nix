{
  lib,
  stdenv,
  proton-run,
}:

stdenv.mkDerivation {
  name = "epicgames";

  src = ./epicgames.desktop;

  dontUnpack = true;

  installPhase = ''
    install -Dm444 $src $out/share/applications/epicgames.desktop
    substituteInPlace $out/share/applications/epicgames.desktop \
      --replace-fail "Exec=" "Exec=${proton-run}/bin/proton-run " \

    install -Dm444 ${./epicgames.png} $out/share/icons/hicolor/256x256/apps/epicgames.png
  '';
}
