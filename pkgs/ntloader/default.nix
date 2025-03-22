{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation rec {
  pname = "ntloader";
  version = "3.0.5-unstable-2025-03-21";

  src = fetchFromGitHub {
    owner = "grub4dos";
    repo = pname;
    rev = "57d3c32c6dc722d80856d34b98aa0cab2d12dc26";
    sha256 = "sha256-/Y+wuG9nkAps6OHjWgfN0G5NQjYmrK23Mup0hYEDbcI=";
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
