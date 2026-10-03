{
  alsa-lib,
  at-spi2-atk,
  autoPatchelfHook,
  cairo,
  cups,
  dbus,
  dpkg,
  expat,
  fetchurl,
  glib,
  gtk3,
  lib,
  libayatana-appindicator,
  libgbm,
  libnotify,
  libsecret,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  makeWrapper,
  nix-update-script,
  nspr,
  nss,
  pango,
  stdenv,
  systemd,
  wrapGAppsHook3,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "dsh-desktop-next";
  version = "2.0.17";
  strictDeps = true;
  __structuredAttrs = true;

  src = fetchurl {
    url = "https://github.com/anywhere-labs/dsh-desktop/releases/download/v${finalAttrs.version}-next/DSH-NEXT-${finalAttrs.version}-next-amd64.deb";
    hash = "sha256-Fw+FQhNj76Kvoc4FVK1AmNbXjE1qv2tM+Rz9X/8EZ28=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libgbm
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    pango
  ];

  # 主程序按 dlopen 而非链接来用这几个：libudev 是硬依赖（ELF NEEDED），libnotify/libsecret/
  # libayatana-appindicator 是运行期按需加载，autoPatchelf 只会把 NEEDED 里的库写进 RPATH。
  runtimeDependencies = [
    libayatana-appindicator
    libnotify
    libsecret
    systemd
  ];

  # deb 里每个原生 addon 都同时带 glibc 与 musl 两份预编译产物，运行时按 libc 挑；musl 那份在
  # glibc 平台永远不会被 dlopen，缺它的解释器属预期。
  autoPatchelfIgnoreMissingDeps = [ "libc.musl-x86_64.so.1" ];

  dontUnpack = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    dpkg-deb -x "$src" extracted
    # Electron 以可执行文件自身位置定位 resources.pak / locales / resources，故整目录搬移、保持同级；
    # 不能放进 $out/bin：wrapGAppsHook3 会把该目录下每个可执行文件都换成 shell 包装（含 .so 与
    # node_modules 里的二进制），libexec 同理。
    install -d "$out/opt/dsh-desktop-next" "$out/share"
    mv "extracted/opt/DSH NEXT/"* "$out/opt/dsh-desktop-next/"
    mv extracted/usr/share/* "$out/share/"

    # 走 Vulkan：deb 不带 EGL/GL，ANGLE 的 native EGL 初始化必然失败、GPU 进程反复重启。
    # 会话 XDG_DATA_DIRS 不含 driver link，Vulkan loader 找不到 ICD（与 vscode 同一根因）。
    makeWrapper "$out/opt/dsh-desktop-next/dsh-desktop-next" "$out/bin/dsh-desktop-next" \
      --add-flags "--use-angle=vulkan" \
      --prefix XDG_DATA_DIRS : "/run/opengl-driver/share"

    substituteInPlace "$out/share/applications/dsh-desktop-next.desktop" \
      --replace-fail 'Exec="/opt/DSH NEXT/dsh-desktop-next"' "Exec=dsh-desktop-next"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--use-github-releases" ];
  };

  meta = {
    description = "An open-source desktop client, built on DeepSeek Harness";
    homepage = "https://github.com/anywhere-labs/dsh-desktop";
    changelog = "https://github.com/anywhere-labs/dsh-desktop/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "dsh-desktop-next";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
