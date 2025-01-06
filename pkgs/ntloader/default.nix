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
    rev = "4cb1c1113297c1dc01c14a8c572cdfff25ca9035";
    sha256 = "sha256-stjg7PNgS/HgbQdoF+B9jNXfGfgbF0rSRB4KtjWRH8A=";
  };

  nativeBuildInputs = [
    libbfd
    libiberty
    libz
    cpio
  ];

  CFLAGS = [ "-Wno-error=array-bounds" ];

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
