{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm,
  pnpmConfigHook,
  nodejs_22,
  electron,
  glib,
}:

let
  # pnpm 11 不再读取 package.json 中的 pnpm.overrides，且不再提升未声明的依赖：
  # 上游（pnpm 9 时代）存在多处「使用但未声明」的依赖（webpack 构建期的
  # @ant-design/icons-vue、运行期的 request/colors/crypto-js 等，以及 core 对
  # @docmirror/mitmproxy 的跨包深层导入）。pnpm11-fix.patch 在 pnpm install
  # 之前统一完成：overrides 迁移、依赖声明补齐、pnpm-lock.yaml 同步。
  # --no-frozen-lockfile 刷新锁文件，再 git diff 出新的 patch。
  patches = [ ./pnpm11-fix.patch ];

  pnpmSetup = ''
    # npmmirror 对大体积包下载较慢，放宽超时与重试
    pnpm config set fetch-timeout 600000
    pnpm config set fetch-retries 6
  '';
in
stdenv.mkDerivation (finalAttrs: {
  pname = "dev-sidecar";
  version = "2.2.0";

  inherit patches;

  src = fetchFromGitHub {
    owner = "docmirror";
    repo = "dev-sidecar";
    rev = "v${finalAttrs.version}";
    hash = "sha256-MrSm9KxU8y6/Imlj0CyQ1wTlvb0BQKECqPEV6KRaqck=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname;
    inherit (finalAttrs) src;
    inherit pnpm patches;
    fetcherVersion = 4;
    prePnpmInstall = pnpmSetup;
    hash = "sha256-awZ4oSKOGsAFFYeea6tvLnB+n2spZxF5TBbciR+HmRU=";
  };

  nativeBuildInputs = [
    pnpm
    pnpmConfigHook
    nodejs_22
  ];

  env = {
    CI = "true"; # 跳过 gui 的 postinstall（electron-builder install-app-deps）
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1"; # 不下载 electron 官方二进制，改用 nixpkgs 的 electron
    NODE_OPTIONS = "--max-old-space-size=8192"; # webpack 构建需要较多内存
  };

  buildPhase = ''
    runHook preBuild

    # 构建 Vue 前端，产物在 packages/gui/dist
    cd packages/gui
    pnpm run build
    cd ../..

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # 整个工作区树复制进 store，node_modules 内的相对符号链接得以保留
    mkdir -p $out/lib/dev-sidecar
    cp -r packages $out/lib/dev-sidecar/packages
    cp -r node_modules $out/lib/dev-sidecar/node_modules

    # CA 不在构建期生成：私钥写入 store 全局可读（0444），且每次重建都会换新信任锚。
    # 改由 modules/nixos/gui/dev-sidecar.nix 首次激活时生成到 ~/.dev-sidecar（私钥 600）
    # 启动脚本：gsettings 等命令需在 PATH 中
    mkdir -p $out/bin
    cat > $out/bin/dev-sidecar <<EOF
    #!${stdenv.shell}
    export PATH="${glib}/bin:$PATH"
    exec ${electron}/bin/electron $out/lib/dev-sidecar/packages/gui "\$@"
    EOF
    chmod +x $out/bin/dev-sidecar

    # 图标与 .desktop
    mkdir -p $out/share/applications $out/share/icons/hicolor/256x256/apps
    cp $out/lib/dev-sidecar/packages/gui/public/logo/win.png $out/share/icons/hicolor/256x256/apps/dev-sidecar.png
    cat > $out/share/applications/dev-sidecar.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=DevSidecar
    Name[zh_CN]=开发者边车
    Comment=开发者边车，加速 GitHub/NPM/Docker Hub 等站点
    Comment[zh_CN]=开发者边车，加速 GitHub/NPM/Docker Hub 等站点
    Exec=dev-sidecar
    Icon=dev-sidecar
    Terminal=false
    Categories=Network;Development;System;
    StartupWMClass=dev-sidecar
    EOF

    runHook postInstall
  '';

  meta = {
    description = "Developer sidecar, proxy https requests to domestic accelerated channels";
    homepage = "https://github.com/docmirror/dev-sidecar";
    license = lib.licenses.mpl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "dev-sidecar";
  };
})
