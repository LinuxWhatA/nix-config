{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  # 运行时 ELF 依赖
  alsa-lib,
  freetype,
  fontconfig,
  gcc,
  glib,
  libgphoto2,
  gst_all_1,
  libpng,
  pulseaudio,
  sane-backends,
  systemdMinimal,
  libusb1,
  libX11,
  libXext,
  ocl-icd,
  pcsclite,
  dbus,
  libGL,
  gnutls,
  vulkan-loader,
}:

stdenv.mkDerivation rec {
  pname = "deepin-wine10-stable";
  version = "10.14deepin11";

  src = fetchurl {
    url = "https://pro-store-packages.uniontech.com/appstore/pool/appstore/d/deepin-wine10-stable/deepin-wine10-stable_${version}_amd64.deb";
    curlOpts = "-A 'Debian APT-HTTP/1.3'";
    hash = "sha256-o0Epgs+xbY4g0pUId5rFrYo7OJpBc37rt/ZXobW5yw8=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    freetype
    fontconfig
    gcc.cc.lib
    glib
    libgphoto2
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    libpng
    pulseaudio
    sane-backends
    systemdMinimal
    libusb1
    libX11
    libXext
    ocl-icd
    pcsclite
    dbus
    libGL
    gnutls
    vulkan-loader
  ];

  autoPatchelfIgnoreMissingDeps = [ "libcapi20.so.3" ];

  dontBuild = true;
  dontConfigure = true;

  unpackPhase = ''
    runHook preUnpack
    mkdir -p build
    dpkg-deb -x $src build
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/deepin-wine10-stable
    cp -r build/opt/deepin-wine10-stable/* $out/opt/deepin-wine10-stable/

    mkdir -p $out/bin
    for bin in wine wineboot winecfg winedbg winefile winepath wineserver; do
      if [ -f "$out/opt/deepin-wine10-stable/bin/$bin" ]; then
        makeWrapper "$out/opt/deepin-wine10-stable/bin/$bin" "$out/bin/deepin-$bin" \
          --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}"
      fi
    done

    if [ -d build/usr/share/applications ]; then
      mkdir -p $out/share/applications
      cp -r build/usr/share/applications/* $out/share/applications/
    fi

    if [ -d build/usr/share/pixmaps ]; then
      mkdir -p $out/share/pixmaps
      cp -r build/usr/share/pixmaps/* $out/share/pixmaps/
    fi

    runHook postInstall
  '';

  meta = with lib; {
    description = "Deepin wine10 stable";
    homepage = "http://www.deepin.org";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
