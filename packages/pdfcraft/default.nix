# 动机：PdfCraft 官方只发二进制（AppImage 等），无源码包，故用 appimageTools 解包（同 tracedraw）。
# 约束：wrapType2 只包装 AppRun（GUI），AppDir 内 pdfcraft-cli 不对外，而两二进制都只直接链接
#       glibc/libgcc_s，窗口/GPU 库（xkbcommon、wayland、vulkan 等）运行时才 dlopen，NixOS 无 FHS
#       布局，故用 buildFHSEnv 直接构建：一个 FHS 环境跑 GUI 与 headless CLI 两个入口，恰好给齐
#       这些运行时库。
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
  pname = "pdfcraft";
  version = "0.22.0";

  src = fetchurl {
    url = "https://github.com/storytold/pdfcraft/releases/download/v${version}/pdfcraft-${version}-linux-x86_64.AppImage";
    hash = "sha256-dx9hsHqvjMF+c8sfk/vohSbyewqoL/MtBxDiw3X0kkg=";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };

  # FHS 入口：按 PDFCRAFT_ENTRY 分流 CLI/GUI，默认 GUI（AppRun 即 usr/bin/pdfcraft）。两分支都
  # env -u 清掉该变量，保证最终进程不残留。
  entry = writeShellScriptBin "pdfcraft-entry" ''
    if [ "''${PDFCRAFT_ENTRY:-}" = "cli" ]; then
      exec env -u PDFCRAFT_ENTRY ${appimageContents}/usr/bin/pdfcraft-cli "$@"
    fi
    exec env -u PDFCRAFT_ENTRY ${appimageContents}/usr/bin/pdfcraft "$@"
  '';
in
buildFHSEnv {
  inherit pname version;
  inherit (appimageTools.defaultFhsEnvArgs) targetPkgs multiPkgs;
  runScript = "${entry}/bin/pdfcraft-entry";
  executableName = "pdfcraft";
  nativeBuildInputs = [ makeWrapper ];
  extraInstallCommands = ''
    # bwrap launcher 藏成隐藏名，两个入口各包一层：GUI 侧 --unset PDFCRAFT_ENTRY 清掉可能从父
    # shell 泄漏来的值（否则终端里 export 过再跑 pdfcraft 会静默跑成 CLI），CLI 侧 --set 显式设
    # 上；CLI 直连 bwrap、不经过 GUI 的 unset 层，故互不干扰。
    mv $out/bin/pdfcraft $out/bin/.pdfcraft-bwrap
    makeWrapper $out/bin/.pdfcraft-bwrap $out/bin/pdfcraft --unset PDFCRAFT_ENTRY
    makeWrapper $out/bin/.pdfcraft-bwrap $out/bin/pdfcraft-cli --set PDFCRAFT_ENTRY cli

    install -Dm444 ${appimageContents}/usr/share/applications/ai.storyteller.pdfcraft.desktop \
      $out/share/applications/ai.storyteller.pdfcraft.desktop

    cp -r --no-preserve=mode ${appimageContents}/usr/share/icons $out/share
  '';

  meta = {
    description = "Open-source, native PDF workbench: read, comment, fill and sign forms, organize, combine, split, edit, redact, protect and export PDFs";
    homepage = "https://github.com/storytold/pdfcraft";
    changelog = "https://github.com/storytold/pdfcraft/releases/tag/v${version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "pdfcraft";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
