{
  lib,
  dpkg,
  pkgs,
  xorg,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  libGL,
  libgcc,
  opencc,
  lsb-release,
  dbus,
  libz,
}:
let
  sources = import ./sources.nix;
in

stdenv.mkDerivation rec {
  pname = "fcitx-sogoupinyin";
  version = sources.version;

  src =
    {
      x86_64-linux = fetchurl {
        url = sources.amd64_url;
        hash = sources.amd64_hash;
      };
      aarch64-linux = fetchurl {
        url = sources.arm64_url;
        hash = sources.arm64_hash;
      };
      mips64el-linux = fetchurl {
        url = sources.loongarch64_url;
        hash = sources.loongarch64_hash;
      };
      loongarch64-linux = fetchurl {
        url = sources.loongarch64_url;
        hash = sources.loongarch64_hash;
      };
    }
    .${stdenv.hostPlatform.system}
      or (throw "${pname}-${version}: ${stdenv.hostPlatform.system} is unsupported.");

  buildInputs = with xorg; [
    libGL
    libgcc
    libxcb
    libX11
    libXScrnSaver
    libXext
    opencc
    lsb-release
    stdenv.cc.cc
    dbus.lib
    libz
    libXcursor
    libXtst
    libXrandr
    pixman
    pkgs.qt5
  ];

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
  ];

  installPhase = ''
    runHook preInstall

    rm -rf opt/sogoupinyin/files/lib/qt5
    rm opt/sogoupinyin/files/bin/qt.conf

    mkdir -p $out
    mv etc $out/
    mv opt $out/
    mv usr/share $out/
    mv usr/lib/*-linux-gnu/fcitx $out/lib

    runHook postInstall
  '';

  meta = {
    description = "Sogou Pinyin for Linux";
    homepage = "https://shurufa.sogou.com/linux";
    license = lib.licenses.unfree;
    maintainers = [ lib.maintainers.linuxwhata ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "mips64el-linux"
      "loongarch64-linux"
    ];
  };
}
