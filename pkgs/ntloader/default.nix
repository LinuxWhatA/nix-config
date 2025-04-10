{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation rec {
  pname = "ntloader";
  version = "3.0.6";

  src = fetchFromGitHub {
    owner = "grub4dos";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-V1F6lQp75/kjhgayxSkUlMK60fCsVK+csRNsNgexd2w=";
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
