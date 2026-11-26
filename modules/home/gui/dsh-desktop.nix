{
  pkgs,
  lib,
  ...
}:

let
  inherit (pkgs) dsh-desktop-next;

  exeName = "dsh-desktop-next";

  # dsh-desktop-next 是 appimageTools.wrapType2 产物：宿主封在 resources/app.asar，
  # 且落点是只读 /nix/store。dsh-purge 的注入流程要「搬走 app.asar → 解包成
  # resources/app/ → 建 app.dshpurge-next 打补丁」，全发生在 <installDir>/resources/ 内，
  # 在只读 store 里必然 EROFS。所以从同一 src 规范提取一份解包树作为镜像源（与运行版同源）。
  extracted = pkgs.appimageTools.extract {
    inherit (dsh-desktop-next) pname version src;
  };

  # 镜像放 state（不污染 ~/.dsh，避免和 dsh-purge 插件自身数据混在一起）。
  # 镜像必须运行时可写，故不能做成只读 store derivation。
  # 量级代价（实测）：extracted 树 1.3G，镜像 = 整树 cp 1.3G + asar 解包出 resources/app
  # （app.asar 单独 270M），合计约 1.9G。store 换 hash 时会 rm -rf + 全量重拷 + 解包，
  # 首次启动有明显延迟，state 分区需预留约 2G。这是运行时可写的必然代价。
  mirrorRoot = "$HOME/.local/state/dsh-desktop-mirror";
  mirrorExe = "${mirrorRoot}/${exeName}";

  # 重建镜像放在 bwrap 之外：避免把 asar/node 拉进 FHS 依赖，失败也能在启动前响亮退出。
  # store 换 hash 才重做；cp 后、asar extract 后各补一次 chmod u+w（归档头多为 555 只读）。
  dshMirrorSetup = pkgs.writeShellScriptBin "dsh-mirror-setup" ''
    set -euo pipefail
    # flock 串行化：连点桌面图标会起多个进程，后到者会在前者复制途中再次 rm -rf，
    # 把镜像切半残缺。锁文件放镜像目录之外，否则随 rm -rf 一起被删、锁形同虚设。
    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.local/state"
    LOCK="$HOME/.local/state/dsh-desktop-mirror.lock"
    exec 9>"$LOCK"
    ${pkgs.util-linux}/bin/flock 9
    SRC=${lib.escapeShellArg (lib.getBin extracted)}
    MARK="${mirrorRoot}/.store-path"
    CUR=$(cat "$MARK" 2>/dev/null || true)
    if [ "$CUR" != "$SRC" ] || [ ! -x "${mirrorExe}" ]; then
      ${pkgs.coreutils}/bin/rm -rf "${mirrorRoot}"
      ${pkgs.coreutils}/bin/mkdir -p "${mirrorRoot}"
      ${pkgs.coreutils}/bin/cp -a "$SRC"/. "${mirrorRoot}/"
      ${pkgs.coreutils}/bin/chmod -R u+w "${mirrorRoot}"
      # 解包 asar 成 resources/app：purge 的 isAiBase/trustedInstallDir 认解包目录，
      # 且只有解包后宿主文件才是可打补丁的散文件。
      ${pkgs.asar}/bin/asar extract "${mirrorRoot}/resources/app.asar" "${mirrorRoot}/resources/app"
      ${pkgs.coreutils}/bin/chmod -R u+w "${mirrorRoot}"
      printf '%s' "$SRC" > "$MARK"
    fi
  '';

  # FHS 环境：AppImage 没自带 libglib 等系统库，原包靠 wrapType2 内部的 buildFHSEnv 提供。
  # 这里复用同一套 appimageTools.defaultFhsEnvArgs（glib/gtk3/nss... 与原包完全一致）。
  # 入口必须经镜像内的 AppRun：它把 AppDir/usr/lib（appindicator/notify/Xss/gconf 等
  # defaultFhsEnvArgs 未覆盖的库）注入 LD_LIBRARY_PATH，并保留上游沙箱探测
  # （unshare -Ur 失败时补 --no-sandbox）。指向 store 内的 AppRun 会让 APPDIR 指回只读树，补丁失效。
  dshMirrorFhs = pkgs.buildFHSEnv {
    name = "${exeName}-mirror-fhs";
    targetPkgs = pkgs: pkgs.appimageTools.defaultFhsEnvArgs.targetPkgs pkgs;
    multiPkgs = pkgs: pkgs.appimageTools.defaultFhsEnvArgs.multiPkgs pkgs;
    runScript = "${mirrorRoot}/AppRun";
  };

  # 启动器：先确保镜像存在且可写（外层，可写 $HOME），再经 FHS 跑镜像，并把
  # DSH_APP/DSH_EXE 指向镜像（desktop.js findDesktopAppExecutable 首选这两个变量）。
  dshPurgeable = pkgs.writeShellScriptBin "dsh-purgeable" ''
    set -euo pipefail
    ${dshMirrorSetup}/bin/dsh-mirror-setup
    export DSH_APP="${mirrorExe}"
    export DSH_EXE="${mirrorExe}"
    exec ${dshMirrorFhs}/bin/${exeName}-mirror-fhs "$@"
  '';
in
{
  home.packages = [
    dshPurgeable
    # asar 不进 packages：dshMirrorSetup 已用 ${pkgs.asar} 绝对路径，不依赖 PATH；
    # 列进 packages 会平白拉入 nodejs 闭包（YAGNI）。偶尔手动解包用 nix shell nixpkgs#asar。
  ];

  # 覆盖原桌面入口：应用菜单/launcher 启动的是可写镜像，而非只读 store。
  # 原包 .desktop 的 Exec 指向 store 解包树，purge 无法注入，故用同名入口顶掉。
  # HM 经 lib.hiPrio 装这份 .desktop，优先级高于包自带入口，同名覆盖生效。
  xdg.desktopEntries.dsh-desktop-next = {
    name = "DSH NEXT";
    exec = "${dshPurgeable}/bin/dsh-purgeable %U";
    terminal = false;
    type = "Application";
    icon = exeName;
    categories = [ "Development" ];
    comment = "DSH Desktop (可写镜像，支持 dsh-purge 注入)";
    # HM desktopEntries 无 startupWMClass 选项；StartupWMClass 属自定义键，经 settings 透传
    settings = {
      StartupWMClass = exeName;
    };
  };

  # 图标原本靠 dsh-desktop-next 包的 extraInstallCommands 安装；包已从 packages.nix 移除，
  # 这里从 extracted 树自带 hicolor 图标，保证 Icon=dsh-desktop-next 可解析。
  xdg.dataFile."icons/hicolor" = {
    source = "${lib.getBin extracted}/usr/share/icons/hicolor";
    recursive = true;
  };
}
