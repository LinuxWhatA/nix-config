# fcitx5-wetypex（WeTypeX）——在 Linux 上通过 Fcitx5 使用微信输入法：原版 macOS 输入核心
# 加一个小型 Mach-O ABI 兼容宿主。按 AUR PKGBUILD 同参打包，NixOS 适配点（为什么）：
#   - 上游 CMakeLists 用 FetchContent 联网拉 libkqueue 与 curl 8.22.0 源码，沙箱无网：
#     FETCHCONTENT_SOURCE_DIR_* 指向预取的固定版本（同 AUR PKGBUILD；目录须是解包后的源码树）。
#   - curl 保留上游默认的内置静态构建，勿改 -DWETYPE_BUNDLED_CURL=OFF：实测本机 nixpkgs
#     curl 8.22.0 导出 curl_ws_* 符号但协议列表无 ws/wss（autotools 未开 WebSocket），桥接
#     运行时探测 ws/wss=false 即拒绝连接——与上游警告的发行版翻车（Ubuntu 24.04）同因。
#   - 注入原版核心的两个桥接 .so（locale/wcwss_bridge）须 clang++ -stdlib=libc++ 编译
#     （Darwin/libc++ ABI），CMake 只按名字找 clang++：故挂 llvmPackages.libcxxClang；
#     其余目标仍走 stdenv 的 gcc/libstdc++（与 Qt6、LibIME 同一 ABI）。
#   - 上游脚本（bin/ 下 8 个 shell 脚本 + setup_runtime.py 的 validate_runtime）按 FHS 把
#     /usr 绑进 bwrap 沙箱取系统库，NixOS 无 /usr：改绑只读 /nix/store（依赖均带 store
#     RPATH，loader 在沙箱内可解析），保留 /lib64（nix-ld 解释器所在）。
#   - bwrap/python3/pw-record/ffmpeg/flock/notify-send/wl-*/pkexec 经 PATH 解析且不在默认
#     profile：包装 8 个入口脚本统一注入 PATH，勿逐个 sed 命令名。
#   - postPatch 三处源码修补（根因见各自注释）：json.hpp 去 JSON_TOKENER_STRICT（中文候选被
#     静默丢弃）；V 工具窗 spawn 前注入 QT_QPA_PLATFORM=xcb（labwc 抢焦点致闪退）；
#     vmode.cpp 无光标矩形时居中（客户端恒不下发，rect 为 0,0）。
{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchzip,
  cmake,
  pkg-config,
  git,
  patchelf,
  llvmPackages,
  boost,
  fcitx5,
  libime,
  json_c,
  openssl,
  curl,
  qt6,
  qt6Packages,
  makeWrapper,
  bubblewrap,
  util-linux,
  python3,
  pipewire,
  ffmpeg,
  libnotify,
  wl-clipboard,
  polkit,
}:

let
  # 上游 CMakeLists 的 FetchContent 目标与固定版本（同 AUR PKGBUILD；目录须是解包后的源码树）
  libkqueueSrc = fetchFromGitHub {
    owner = "mheily";
    repo = "libkqueue";
    rev = "46a3e130f88b0b0742575dcb01d77e336538024b";
    hash = "sha256-bUtjzGxQHJkd9SxlXpA8xJ4hT0IeMHrlcfRLMTdT59k=";
  };

  curlSrc = fetchzip {
    url = "https://curl.se/download/curl-8.22.0.tar.xz";
    hash = "sha256-3GBq7T5iU08VargRfd86qmAnheWRRd7ijH55PCw+ghY=";
  };

  runtimePath = lib.makeBinPath [
    bubblewrap
    util-linux # flock
    python3
    pipewire # pw-record
    ffmpeg
    libnotify # notify-send
    wl-clipboard
    polkit # pkexec
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "fcitx5-wetypex";
  version = "2.2.3.657-9";

  src = fetchFromGitHub {
    owner = "panxuc";
    repo = "fcitx5-wetypex";
    rev = "v${finalAttrs.version}";
    hash = "sha256-61WToYlSIYantWlNBDrepnWJ8ezSjnV58fuMEoaCMEc=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    git # libkqueue 的 CMakeLists 用 git rev-parse 取提交号，缺 git 会直接致命失败
    patchelf # postFixup 给引擎宿主补 libc++ RPATH（勿依赖 stdenv 的 ambient 副本）
    llvmPackages.libcxxClang # 提供 clang++（桥接 .so 专用，主编译器仍是 stdenv gcc）
    qt6.wrapQtAppsHook
    makeWrapper
    python3 # postPatch 的插入式修补；运行时那份在 buildInputs 尾段，启用 strictDeps 后不进 PATH
  ];

  buildInputs = [
    boost # LibIMEPinyinConfig 有 find_dependency(Boost)
    fcitx5
    libime
    qt6Packages.fcitx5-qt
    qt6.qtbase
    qt6.qtsvg
    qt6.qtwebengine
    json_c
    openssl # BundledCurl.cmake 的 find_package(OpenSSL)（静态 libcurl 链系统 libssl）
    curl
  ]
  # 以下仅运行时需要，经包装脚本注入 PATH（进闭包保证 nix run/直接执行也可解析）
  ++ [
    bubblewrap
    util-linux
    python3
    pipewire
    ffmpeg
    libnotify
    wl-clipboard
    polkit
  ];

  cmakeFlags = [
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_KQUEUE" "${libkqueueSrc}")
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_WETYPEX_CURL" "${curlSrc}")
  ];

  # json-c 0.18 的 STRICT 用有符号 char 比 0x1f，非 ASCII 字节被当控制字符拒掉，含中文的
  # 引擎回复整行解析失败并被静默丢弃（无候选框、空格无响应）；nixpkgs 26.11 钉的正是带缺陷的
  # json-c-0.18-20240915（0.17 无该检查、Arch 已 ≥0.19，故只本机中招）。对端是受信本地引擎
  # 宿主，去 STRICT 无损安全（VALIDATE_UTF8 与 parse() 尾部逐字节检查仍在）。
  postPatch = ''
    substituteInPlace src/common/json.hpp \
      --replace-fail 'JSON_TOKENER_STRICT | JSON_TOKENER_VALIDATE_UTF8' 'JSON_TOKENER_VALIDATE_UTF8' \
      --replace-fail 'JSON_TOKENER_STRICT);' '0);'

    # 插入类改动留在 python：nix 缩进字符串按"公共最小缩进"剥离，故 C++ 片段一律写成单行
    # python 字符串（显式 \n）；本块内若出现缩进更小的行，基准即变、PYEOF 不再顶格而 heredoc
    # 永不终止。锚点唯一由 assert 兜底；--replace-fail 只保证"匹配到"（0 次即失败，全量替换）。
    python3 - <<'PYEOF'
    import pathlib

    def sub(path, anchor, insert):
        p = pathlib.Path(path)
        s = p.read_text()
        assert s.count(anchor) == 1, "anchor not unique: %r" % anchor
        p.write_text(s.replace(anchor, insert + anchor))

    sub("src/plugin/wetype.cpp", '#include "config.hpp"\n', '#include <stdlib.h>\n')
    # 原生 Wayland 下 labwc 会给新映射的 toplevel 键盘焦点，客户端 IM 随即发 Reset，插件的
    # reset() 便杀掉工具窗（"闪退"）；X11 侧 WindowDoesNotAcceptFocus 落成 input=False，WM
    # 不聚焦它，故有 XWayland 时走 xcb，无则不动（KDE/GNOME 本就不抢焦点）。
    # setenv 作用于整个 fcitx5 进程、此后 spawn 的子进程都继承：引擎宿主与 syncd 皆非 Qt 故无碍；
    # 将来若 spawn Qt 子进程，须改为只给 posix_spawn 传局部 environ。
    sub("src/plugin/wetype.cpp", '    pid_t child = -1;\n',
        '    if (!getenv("QT_QPA_PLATFORM") && getenv("DISPLAY"))\n'
        '      setenv("QT_QPA_PLATFORM", "xcb", 0);\n')

    sub("src/vmode.cpp", '#include <QApplication>\n', '#include <QScreen>\n')
    # 光标矩形恒 (0,0,0,0)（客户端从不下发，连打拼音时也是）→ 窗口只能停在左上角，故无坐标时
    # 按屏幕可用区居中；勿再试"缓存最后一次有效矩形"（本机填不上）。客户端若下发仍精确落位。
    sub("src/vmode.cpp", '  window.move(x, y);\n',
        '  if (x == 0 && y == 0) {\n'
        '    if (auto *screen = QGuiApplication::primaryScreen()) {\n'
        '      const auto g = screen->availableGeometry();\n'
        '      x = g.center().x() - window.width() / 2;\n'
        '      y = g.center().y() - window.height() / 2;\n'
        '    }\n'
        '  }\n')
    PYEOF
  '';

  postInstall = ''
    # bwrap 沙箱原按 FHS 绑 /usr（NixOS 上是空目录，取不到库）：改绑只读 /nix/store，依赖
    # 均带 store RPATH，loader 在沙箱内可解析；/lib64 保留（nix-ld 解释器在此）。
    sed -i \
      -e 's|--ro-bind /usr /usr --symlink usr/lib /lib --ro-bind /lib64 /lib64|--ro-bind /nix/store /nix/store --ro-bind /lib64 /lib64|g' \
      -e 's| --symlink usr/bin /bin||g' \
      "$out"/bin/fcitx5-wetypex-{account,ai,backend,setup,sync,syncd,update,voice}

    # setup_runtime.py 的 validate_runtime 自拼同一套 FHS 绑定（漏了它，
    # fcitx5-wetypex-setup --check 必报 engine validation failed：沙箱内解释器
    # /lib64/ld-linux 的 nix-ld 符号目标在未绑定的 /nix/store，execvp ENOENT）。
    sed -i \
      -e "s|'--ro-bind','/usr','/usr','--symlink','usr/lib','/lib',|'--ro-bind','/nix/store','/nix/store',|" \
      -e "s|'--symlink','usr/bin','/bin',||" \
      "$out/share/fcitx5-wetypex/setup_runtime.py"

    # NixOS 的信任根是 /etc/ssl/certs → /etc/static/ssl/certs → store 的链接链，上游按
    # FHS 只绑了首段：/etc/static 缺席则沙箱内 CA 悬空，引擎 TLS 校验失败(code:60)、握手
    # error:2001，表现为配对签不出匹配码、云候选恒不可用；仅带 /etc 绑定的三个脚本涉及。
    fhs_ca='--ro-bind-try /etc/ca-certificates /etc/ca-certificates'
    substituteInPlace "$out"/bin/fcitx5-wetypex-{account,ai,backend} \
      --replace-fail "$fhs_ca" "--ro-bind /etc/static/ssl /etc/static/ssl $fhs_ca"

    for f in account ai backend setup sync syncd update voice; do
      wrapProgram "$out/bin/fcitx5-wetypex-$f" --prefix PATH : "${runtimePath}"
    done
  '';

  # 引擎宿主按 SONAME dlopen("libc++.so.1")/libc++abi（上游假设 libc++ 在系统 loader 路径，
  # 如 Arch 的 /usr/lib），NixOS 须让 libc++ 进宿主自己的 RUNPATH 才能解析。fixup 的
  # shrink-rpath 只认 DT_NEEDED，会把这条"未被直接链接"的项删掉，故放到 postFixup 补。
  postFixup = ''
    patchelf --add-rpath "${llvmPackages.libcxx}/lib" \
      "$out/lib/fcitx5-wetypex/wetypex-engine-host"
  '';

  meta = {
    description = "Fcitx5 微信输入法兼容层（WeTypeX）：在 Linux 上运行原版 macOS 输入核心";
    homepage = "https://github.com/panxuc/fcitx5-wetypex";
    license = with lib.licenses; [
      mit
      isc
      bsd2
      curl
    ];
    platforms = [ "x86_64-linux" ];
  };
})
