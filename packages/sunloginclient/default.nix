{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  desktop-file-utils,
  wrapGAppsHook3,
  gtk3,
  gdk-pixbuf,
  libnotify,
  libepoxy,
  webkitgtk_4_1,
  libX11,
  libxdamage,
  libxcomposite,
  libXtst,
  libappindicator-gtk3,
  glibc,
  pipewire,
}:

let
  # bin/awesun 需要 crypt@GLIBC_2.2.5，而 nixpkgs 的 libxcrypt 只提供
  # libcrypt.so.2 / XCRYPT_2.0，故补一个同名同版本的空 stub。
  libcryptStub = stdenv.mkDerivation {
    name = "libcrypt-stub";
    dontUnpack = true;
    dontBuild = true;
    installPhase = ''
            mkdir -p $out/lib
            cat > $out/lib/version.script << 'VEOF'
      GLIBC_2.2.5 {
          global: *; local: *;
      };
      VEOF
            ${stdenv.cc}/bin/gcc -shared \
              -Wl,--version-script=$out/lib/version.script \
              -Wl,-soname,libcrypt.so.1 \
              -o $out/lib/libcrypt.so.1 \
              -xc /dev/null
            rm $out/lib/version.script
    '';
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "sunloginclient";
  version = "16.5.0.30560";

  src = fetchurl {
    url = "https://down.oray.com/sl/linux/awesun-${finalAttrs.version}-x86_64.deb";
    hash = "sha256-7aP//m1TJK+8T5OfDLhcCLeFHvrTwBh4YhR07HUD0Q8=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    desktop-file-utils
    wrapGAppsHook3
  ];

  buildInputs = [
    gtk3
    gdk-pixbuf
    libnotify
    libepoxy
    webkitgtk_4_1
    libX11
    libxdamage
    libxcomposite
    libXtst
    libappindicator-gtk3
    libcryptStub
  ];
  runtimeDependencies = [ glibc ];
  patchelfFlags = [ "--force-rpath" ];

  # 部分组件（录屏/远程音频）在启动时 dlopen libpipewire，非 NEEDED 依赖，
  # autoPatchelfHook 不会处理，需通过 LD_LIBRARY_PATH 提供。
  # 注意：gappsWrapperArgs 必须在 preFixup 阶段追加（wrap-gapps-hook 会在
  # hook 开头重置该数组，顶层属性值会被丢弃）
  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ pipewire ]}"
    )
  '';

  # 剥离后 daemon 会连接失败（AUR b3a3824），保持上游二进制原样
  dontStrip = true;
  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    mkdir -p build
    dpkg-deb -x $src build
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share $out/opt
    cp -r build/usr/local/awesun $out/opt/

    ln -s ../opt/awesun/awesun $out/bin/sunloginclient
    ln -s ../opt/awesun/bin/awesun $out/bin/awesun

    mkdir -p $out/share/applications $out/share/pixmaps
    cp build/usr/share/applications/awesun.desktop $out/share/applications/
    cp build/usr/local/awesun/awesun.png $out/share/pixmaps/sunloginclient.png
    substituteInPlace $out/share/applications/awesun.desktop \
      --replace-fail "/usr/local/awesun/awesun.png" "sunloginclient" \
      --replace-fail "/usr/local/awesun/awesun" "sunloginclient" \
      --replace-fail "Categories=Network;RemoteControl;" "Categories=Network;X-RemoteControl;"
    desktop-file-validate $out/share/applications/awesun.desktop

    runHook postInstall
  '';

  meta = {
    description = "Sunlogin remote desktop client (向日葵远程控制)";
    homepage = "https://sunlogin.oray.com";
    license = lib.licenses.unfree;
    mainProgram = "sunloginclient";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
