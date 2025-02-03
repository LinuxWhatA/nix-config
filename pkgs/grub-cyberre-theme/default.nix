{
  stdenvNoCC,
  lib,
  fetchFromGitHub,
  ...
}:

stdenvNoCC.mkDerivation {
  pname = "grub-cyberre-theme";
  version = "1.0";
  src = fetchFromGitHub {
    owner = "metgen";
    repo = "CyberReFresh";
    rev = "b4eb32c0e81fdb293f0ed2851e9cd082e7f26337";
    hash = "sha256-MeCEdYnqEoqY6qDl/uGSz4NJo3xlK87AaAb7l3R8eCQ=";
  };

  installPhase = ''
    mkdir -p $out/grub/themes
    cp -r CyberRe $out/grub/themes
  '';

  meta = {
    platforms = lib.platforms.all;
  };
}
