{
  stdenvNoCC,
  lib,
  fetchFromGitHub,
  ...
}:

stdenvNoCC.mkDerivation {
  pname = "plymouth-550w-theme";
  version = "1.0";
  src = fetchFromGitHub {
    owner = "Davidyz";
    repo = "plymouth-theme-550w";
    rev = "e648a4d90f3748b170385e3b4e4d814bb5b93a0e";
    hash = "sha256-nEZqLhMxMQWfxBSTpmjiUDqrYGii0J6b6f+ivM4zIT0=";
  };

  installPhase = ''
    mkdir -p $out/share/plymouth/themes

    substituteInPlace assets/550w.plymouth \
      --replace-fail "ImageDir=/usr" "ImageDir=$out"

    cp -rT assets $out/share/plymouth/themes/550w
  '';

  meta = {
    homepage = "https://github.com/Davidyz/plymouth-theme-550w";
    platforms = lib.platforms.all;
  };
}
