{
  lib,
  stdenv,
  fetchFromGitHub,
  libbfd,
  libiberty,
  libz,
  cpio,
}:

stdenv.mkDerivation rec {
  pname = "ntloader";
  version = "2.0.1";

  src = fetchFromGitHub {
    owner = "grub4dos";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-v7jIKcxxLeLvd4ymnImkFS/iwxwySDmAO5+QFytkU24=";
  };

  nativeBuildInputs = [
    libbfd
    libiberty
    libz
    cpio
  ];

  patches = [
    ./startup.S.patch
    ./callback.S.patch
  ];

  installPhase = ''
    mkdir -p $out
    cp ntloader $out
    find utils/rootfs | cpio -o -H newc > $out/initrd.cpio
  '';

  meta = with lib; {
    description = "Windows NT6+ OS/VHD/WIM loader";
    homepage = "https://github.com/grub4dos/ntloader";
    license = licenses.gpl2;
    platforms = platforms.linux;
  };
}
