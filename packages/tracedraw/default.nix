# 动机：官方只发 AppImage 二进制（无源码包），故用 appimageTools 解包（同 pdfcraft）。
# 约束：两个二进制都只直接链 glibc，窗口/GPU 库（wayland、xkbcommon、vulkan 等）运行时才 dlopen，
#       NixOS 无 FHS 布局 → 用 buildFHSEnv 供齐；FHS 内 fontconfig 可见含 CJK 的系统字体，
#       缩略图中文文字不变豆腐块。
# 取舍：入口分流——TRACEDRAW_ENTRY=cli 走 headless 渲染（缩略图用），否则 GUI；两入口都经 bwrap
#       进同一 FHS。desktop/图标/缩略图由 extraInstallCommands 装 $out/share（AppImage 自装
#       会写 ~/.local/share，store 里不可变）。
{
  appimageTools,
  buildFHSEnv,
  desktop-file-utils,
  fetchurl,
  lib,
  makeWrapper,
  writeShellScriptBin,
  writeText,
}:
let
  pname = "tracedraw";
  version = "0.52.0";

  src = fetchurl {
    url = "https://github.com/tracedraw/tracedraw/releases/download/v${version}/tracedraw-${version}-linux-amd64.AppImage";
    hash = "sha256-JDCDH7sNL89OMmL3lriu2mDpV7crsCPKH5+2SJBxJ7s=";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };

  # FHS 入口：TRACEDRAW_ENTRY=cli 走 headless CLI，否则 GUI；两分支都清掉该变量，防终端 export 泄漏。
  entry = writeShellScriptBin "tracedraw-entry" ''
    if [ "''${TRACEDRAW_ENTRY:-}" = "cli" ]; then
      exec env -u TRACEDRAW_ENTRY ${appimageContents}/usr/bin/tracedraw-cli "$@"
    fi
    exec env -u TRACEDRAW_ENTRY ${appimageContents}/usr/bin/tracedraw "$@"
  '';

  # .cdr 缩略图（freedesktop .thumbnailer，KIO 以 QProcess 起 Exec；%i=输入、%o=输出、%s=尺寸）。
  # .cdr 的真实 MIME 是 application/vnd.corel-draw，上游只写 application/x-cdr 历史别名，故必须补
  # canonical——否则 KDE 匹配不到 .cdr（打开方式同理，见下方 desktop-file-edit）。
  # .tdraw 不在此列：它没有已注册 MIME（用户级包放 share/mime/packages 不会被 update-mime-database
  # 扫到，注册也起不了作用），KDE 按 MIME 匹配，留着是死项。
  thumbnailer = writeText "tracedraw.thumbnailer" ''
    [Thumbnailer Entry]
    TryExec=tracedraw-cli
    Exec=tracedraw-cli thumbnail %i %o %s
    MimeType=application/x-cdr;application/vnd.corel-draw;
  '';
in
buildFHSEnv {
  inherit pname version;
  inherit (appimageTools.defaultFhsEnvArgs) targetPkgs multiPkgs;
  runScript = "${entry}/bin/tracedraw-entry";
  executableName = "tracedraw";
  nativeBuildInputs = [
    makeWrapper
    desktop-file-utils
  ];
  extraInstallCommands = ''
    # bwrap launcher 藏成隐藏名，两个入口各包一层：GUI 侧 --unset 清掉可能从父 shell 泄漏来的
    # TRACEDRAW_ENTRY，CLI 侧 --set 显式设上；CLI 直连 bwrap、不经过 GUI 的 unset 层，互不干扰。
    mv $out/bin/tracedraw $out/bin/.tracedraw-bwrap
    makeWrapper $out/bin/.tracedraw-bwrap $out/bin/tracedraw --unset TRACEDRAW_ENTRY
    makeWrapper $out/bin/.tracedraw-bwrap $out/bin/tracedraw-cli --set TRACEDRAW_ENTRY cli

    install -Dm444 ${appimageContents}/usr/share/applications/tracedraw.desktop \
      $out/share/applications/tracedraw.desktop
    # 上游 desktop 只写 application/x-cdr 历史别名；补 canonical 类型，KDE“打开方式”候选才认 .cdr。
    desktop-file-edit --add-mime-type=application/vnd.corel-draw \
      $out/share/applications/tracedraw.desktop

    cp -r --no-preserve=mode ${appimageContents}/usr/share/icons $out/share

    install -Dm444 ${thumbnailer} $out/share/thumbnailers/tracedraw.thumbnailer
  '';

  meta = {
    description = "TraceDraw - open-source vector illustration editor";
    homepage = "https://github.com/tracedraw/tracedraw";
    changelog = "https://github.com/tracedraw/tracedraw/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "tracedraw";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
