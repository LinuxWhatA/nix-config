{
  lib,
  stdenvNoCC,
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
  # winex11 只在运行时对这些 X 扩展做 dlopen（不是 DT_NEEDED），不进 LD_LIBRARY_PATH 会静默降级
  libXfixes,
  libXrender,
  libXcursor,
  libXrandr,
  libXi,
  libXinerama,
  libXcomposite,
  libxxf86vm,
  ocl-icd,
  pcsclite,
  dbus,
  libGL,
  gnutls,
  vulkan-loader,
}:

stdenvNoCC.mkDerivation rec {
  pname = "deepin-wine10-stable";
  version = "10.14deepin11";

  src = fetchurl {
    url = "https://pro-store-packages.uniontech.com/appstore/pool/appstore/d/deepin-wine10-stable/deepin-wine10-stable_${version}_amd64.deb";
    # 上游 CDN 只接受 Debian 的 UA，其余一律 403；必须是列表形式，字符串会被 concatTo 按空白拆成多个 argv
    curlOptsList = [
      "-A"
      "Debian APT-HTTP/1.3"
    ];
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
    libXfixes
    libXrender
    libXcursor
    libXrandr
    libXi
    libXinerama
    libXcomposite
    libxxf86vm
    ocl-icd
    pcsclite
    dbus
    libGL
    gnutls
    vulkan-loader
  ];

  # libcapi20 在 nixpkgs 无对应包，且仅 CAPI 场景会加载该模块，放行以免整体构建失败
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

    mkdir -p $out/opt
    cp -r build/opt/deepin-wine10-stable $out/opt/

    mkdir -p $out/bin
    for bin in wine wineboot winecfg winedbg winefile winepath wineserver regedit regsvr32 msiexec; do
      if [ -f "$out/opt/deepin-wine10-stable/bin/$bin" ]; then
        makeWrapper "$out/opt/deepin-wine10-stable/bin/$bin" "$out/bin/deepin-$bin" \
          --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}"
      fi
    done

    # 上游入口的等价物：WINEDEBUG 未给出时静音，否则 wine 默认会刷调试输出
    makeWrapper "$out/opt/deepin-wine10-stable/bin/wine" "$out/bin/deepin-wine10-stable" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}" \
      --set-default WINEDEBUG -all

    # 上游 desktop/pixmap 指向 Debian 绝对路径，搬进 store 也是坏链接，故不搬运

    runHook postInstall
  '';

  meta = with lib; {
    description = "Deepin wine10 stable";
    homepage = "http://www.deepin.org";
    license = licenses.unfree;
    mainProgram = "deepin-wine";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
