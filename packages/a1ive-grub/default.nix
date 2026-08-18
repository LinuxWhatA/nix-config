{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchgit,
  flex,
  bison,
  python3,
  autoconf,
  automake,
  libtool,
  bash,
  gettext,
  ncurses,
  libusb-compat-0_1,
  freetype,
  lvm2,
  unifont,
  pkg-config,
  help2man,
  buildPackages,
}:

let
  # bootstrap.conf 中固定的 gnulib 版本（GRUB 2.11 时代）
  gnulib = fetchgit {
    url = "https://github.com/coreutils/gnulib.git";
    rev = "d271f868a8df9bbec29049d01e056481b7a1a263";
    hash = "sha256-AON1MEfEbSTZMeDDwawRDUD22/4+jIiWYnk35xg7ZSk=";
  };
in

stdenv.mkDerivation {
  pname = "a1ive-grub";
  version = "2.11";

  src = fetchFromGitHub {
    owner = "a1ive";
    repo = "grub";
    rev = "77322411ddd574b461ca7c2b666c881bae51d8bd";
    hash = "sha256-YH3569EqFna4cY5I+YXct+mcRECFvTVeVbOJUdl5oVA=";
  };

  nativeBuildInputs = [
    bison
    flex
    python3
    pkg-config
    gettext
    autoconf
    automake
    libtool
    help2man
  ];
  buildInputs = [
    ncurses
    libusb-compat-0_1
    freetype
    lvm2
    bash
  ];

  hardeningDisable = [ "all" ];

  NIX_CFLAGS_COMPILE = [ "-std=gnu11" ];

  preConfigure = ''
    patchShebangs .

    cp -r ${gnulib} $NIX_BUILD_TOP/gnulib-writable
    chmod -R u+w $NIX_BUILD_TOP/gnulib-writable

    ./bootstrap --no-git --gnulib-srcdir=$NIX_BUILD_TOP/gnulib-writable

    # 与 nixpkgs grub2 一致：GRUB 在 /usr/share/fonts 各子目录（含 X11/misc）搜索
    # unifont.{pcf,pcf.gz,bdf,bdf.gz,ttf,ttf.gz} 作为 FONT_SOURCE 生成 .pf2
    substituteInPlace ./configure --replace-fail /usr/share/fonts ${unifont}/share/fonts
  '';

  configureFlags = [
    "--disable-werror"
    "--with-platform=efi"
    "--target=x86_64"
  ];

  postInstall = ''
    sed -i $out/lib/grub/*/modinfo.sh -e "/grub_target_cppflags=/ s|'.*'|' '|"
    substituteInPlace $out/lib/grub/*/modinfo.sh \
      --replace ${buildPackages.bash} ${bash}/bin/bash

    cp -f $src/makepkg/arch/x64/builtin.txt $out/builtin.txt
    cp -f ${./bootmgfw.efi} $out/bootmgfw.efi
  '';

  meta = {
    description = "Fork of GRUB 2 (a1ive) to add various features, built from source";
    homepage = "https://github.com/a1ive/grub";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };
}
