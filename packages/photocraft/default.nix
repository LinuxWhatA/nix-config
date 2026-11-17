# 动机：PhotoCraft 官方 release 只附二进制安装包（AppImage/deb/rpm/…），无源码构建产物，
#       故用 appimageTools 解包，省去自建 Rust 工具链与整套 crate 的源码编译。
# 约束：wrapType2 只包装 AppRun（GUI），AppDir 内 photocraft-cli 不对外；两二进制都只直接链接
#       glibc/libgcc_s，窗口/GPU 库（xkbcommon、wayland、vulkan 等）运行时才 dlopen，NixOS 无 FHS
#       布局，故用 buildFHSEnv 直接构建：一个 FHS 环境跑 GUI 与 headless CLI 两个入口
#       （PHOTOCRAFT_ENTRY 分流，GUI 侧须 unset 防终端里泄漏该变量），恰好给齐这些运行时库。
# 取舍：AppRun 的桌面集成只在 APPIMAGE 非空（真 AppImage 运行时）才写 ~/.local/share，这里不设
#       该变量、自动跳过，launcher/图标改由 extraInstallCommands 装进 $out/share 走系统路径。
{
  appimageTools,
  buildFHSEnv,
  fetchurl,
  lib,
  makeWrapper,
  writeShellScriptBin,
}:
let
  pname = "photocraft";
  version = "0.23.1";

  src = fetchurl {
    url = "https://github.com/storytold/photocraft/releases/download/v${version}/photocraft-${version}-linux-x86_64.AppImage";
    hash = "sha256-BXR7PlJ+HgoMHeOZcDYc84yPyn6NPjYB7yCC+w5t0X8=";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };

  # FHS 入口：按 PHOTOCRAFT_ENTRY 分流 CLI/GUI，默认 GUI。两分支都 env -u 清掉该变量，
  # 确保最终进程不残留（防父 shell 泄漏劫持 GUI 的防御在下方 wrapper）。
  entry = writeShellScriptBin "photocraft-entry" ''
    if [ "''${PHOTOCRAFT_ENTRY:-}" = "cli" ]; then
      exec env -u PHOTOCRAFT_ENTRY ${appimageContents}/usr/bin/photocraft-cli "$@"
    fi
    exec env -u PHOTOCRAFT_ENTRY ${appimageContents}/usr/bin/photocraft "$@"
  '';
in
buildFHSEnv {
  inherit pname version;
  inherit (appimageTools.defaultFhsEnvArgs) targetPkgs multiPkgs;
  runScript = "${entry}/bin/photocraft-entry";
  executableName = "photocraft";
  nativeBuildInputs = [ makeWrapper ];
  extraInstallCommands = ''
    # 藏起 bwrap launcher，两个对外入口各包一层：GUI 侧 --unset PHOTOCRAFT_ENTRY 清掉可能
    # 从父 shell 泄漏来的值（否则终端里 export 过再跑 photocraft 会静默跑成 CLI），CLI 侧 --set
    # 显式设上；CLI 直连 bwrap、不经过 GUI 的 unset 层，故互不干扰。
    mv $out/bin/photocraft $out/bin/.photocraft-bwrap
    makeWrapper $out/bin/.photocraft-bwrap $out/bin/photocraft --unset PHOTOCRAFT_ENTRY
    makeWrapper $out/bin/.photocraft-bwrap $out/bin/photocraft-cli --set PHOTOCRAFT_ENTRY cli

    install -Dm444 ${appimageContents}/usr/share/applications/ai.storyteller.photocraft.desktop \
      $out/share/applications/ai.storyteller.photocraft.desktop

    cp -r --no-preserve=mode ${appimageContents}/usr/share/icons $out/share
  '';

  meta = {
    description = "PhotoCraft - open-source Photoshop reimplementation in pure Rust";
    homepage = "https://github.com/storytold/photocraft";
    changelog = "https://github.com/storytold/photocraft/releases/tag/v${version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "photocraft";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
