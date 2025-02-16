{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation rec {
  pname = "ntloader";
  version = "3.0.3-unstable-2025-02-16";

  src = fetchFromGitHub {
    owner = "grub4dos";
    repo = pname;
    rev = "17c0e3004371e0850210039f4ab4dd78d65e8cc0";
    sha256 = "sha256-atUSgxGddBoNMxF23lMV4SApNYACjCJWf5dOhA6aLaY=";
  };

  makeFlags = [
    "ntloader"
    "initrd.cpio"
  ];

  installPhase = ''
    install -D ntloader -t $out
    install -D initrd.cpio -t $out
  '';

  meta = {
    description = "bootloader for NT6+ WIM, VHD and VHDX images";
    homepage = "https://github.com/grub4dos/ntloader";
    license = lib.licenses.gpl3Only;
    platforms = [
      "x86-linux"
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
