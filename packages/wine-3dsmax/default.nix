{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchurl,
  makeWrapper,
  wineWow64Packages,
  winetricks,
  dxvk,
  curl,
  python3,
  bash,
  xdg-utils,
  shared-mime-info,
  desktop-file-utils,
  coreutils,
  gnused,
  gnugrep,
  gnumake,
  pkgsCross,
  ...
}:
let
  # 随包附带，新建 prefix 时离线装配，省去运行时再走 winetricks 下载。
  monoMsi = fetchurl {
    url = "https://dl.winehq.org/wine/wine-mono/11.3.0/wine-mono-11.3.0-x86.msi";
    hash = "sha256-3y38FmXCURiC58q9Vur9DAo9lOWn6G+Wknf2wYnUGNM=";
  };

  repo = fetchFromGitHub {
    owner = "cl0nazepamm";
    repo = "3dsmax-wine";
    rev = "a6f9583142657ce59d59bb0028e53ec897e8bd6c";
    hash = "sha256-z2YxYkEC+dLS7RqYZQN5EuQjQTaVKrmHe8WnesU4PYo=";
  };

  # 上游在运行时把重编译模块盖到 Gentoo 的 /usr/lib/wine-vanilla-11.0 私有副本上；NixOS 没有这个
  # 可写系统树，改为构建期把同一补丁序列打到 wine 11.0 源码，产物就是私有 wine 树。
  # 补丁按 11.0 源码行号生成，版本漂移会被 patch 模糊匹配掩盖，故锁死版本让升级显式失败。
  patchedWine =
    let
      wine = wineWow64Packages.stable;
    in
    assert lib.assertMsg (
      wine.version == "11.0"
    ) "3dsmax-wine 补丁仅适用于 wine 11.0，当前 ${wine.version}；升级 nixpkgs 后须同步更新 rev";
    wine.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        for p in ${repo}/patches/wine-11.0/*.patch; do
          patch -p1 --batch -i "$p" || exit 1
        done
      '';
    });

  # FIXME: 上游 Wine 11 无法合成跨进程子窗口（WebView2 面板空白/黑），dcomp 每帧刷屏；
  # 上游修好后删掉 err-dcomp 恢复完整错误输出；其余错误仍保留以便响亮失败。
  defaultWineDebug = "-all,err+all,err-dcomp";

  runtimeTools = [
    patchedWine
    winetricks
    curl
    python3
    xdg-utils
    shared-mime-info
    desktop-file-utils
    coreutils
    gnused
    gnugrep
  ];
in
stdenvNoCC.mkDerivation {
  pname = "wine-3dsmax";
  version = "0-unstable-2026-10-14";

  src = repo;

  nativeBuildInputs = [
    makeWrapper
    gnumake
    bash
    python3
    pkgsCross.mingwW64.stdenv.cc
  ];

  dontConfigure = true;

  # patchShebangs 修掉 #!/bin/bash 与 #!/usr/bin/env python3；store 只读，日志/下载改落 XDG 目录。
  postPatch = ''
    patchShebangs scripts
    substituteInPlace scripts/env.sh \
      --replace-fail 'export WINEPREFIX="$HOME/.wine-3dsmax"' \
                     'export WINEPREFIX="''${WINEPREFIX:-$HOME/.wine-3dsmax}"' \
      --replace-fail 'export WINEROOT="$HOME/opt/wine-11.0-patched/usr/lib/wine-vanilla-11.0"' \
                     'export WINEROOT="${patchedWine}"' \
      --replace-fail 'export PATH="$WINEROOT/bin:$PATH"' \
                     'export PATH="$WINEROOT/bin:${lib.makeBinPath runtimeTools}:$PATH"' \
      --replace-fail 'export LOGS="$REPO/logs"' \
                     'export LOGS="''${XDG_STATE_HOME:-$HOME/.local/state}/wine-3dsmax/logs"' \
      --replace-fail 'export WINEDEBUG="''${WINEDEBUG:--all,err+all}"' \
                     'export WINEDEBUG="''${WINEDEBUG:-${defaultWineDebug}}"'
    substituteInPlace scripts/install-identity-manager.sh \
      --replace-fail 'D="$REPO/downloads/idmgr-1.12.0.7"' \
                     'D="''${XDG_CACHE_HOME:-$HOME/.cache}/wine-3dsmax/idmgr-1.12.0.7"' \
      --replace-fail '[ -f "$REPO/tools/sigcheck.exe" ] || make -C "$REPO/tools" sigcheck.exe' \
                     '[ -f "$REPO/tools/sigcheck.exe" ] || { echo "缺 $REPO/tools/sigcheck.exe：包不完整" >&2; exit 1; }'
    # 桌面项落在 $HOME，硬编码 $REPO 会在 GC 后悬空；统一走 PATH 上的包装入口
    substituteInPlace scripts/install-launcher.sh \
      --replace-fail 'Exec="$REPO/scripts/run-3dsmax.sh" %f' \
                     'Exec=wine-3dsmax run %f' \
      --replace-fail 'Comment=Autodesk 3ds Max 2027 (patched Wine, $REPO)' \
                     'Comment=Autodesk 3ds Max 2027 (patched Wine)'
    substituteInPlace scripts/install-url-handler.sh \
      --replace-fail 'Exec="$REPO/scripts/adsk-url-handler.sh" %u' \
                     'Exec=wine-3dsmax adsk-url-handler %u'
    substituteInPlace scripts/setup-prefix.sh \
      --replace-fail 'winetricks -q win10 dxvk' \
                     '"$REPO/scripts/setup-runtimes.sh"'
  '';

  # sigcheck.exe 供安装流程校验 Identity Manager 安装包；预编译可免去运行时 mingw 与写 store。
  # GCC 的 MinGW wrapper 用 specs 注入 -lmcfgthread，但单独调用时找不到导入库，故补一条 -L。
  buildPhase = ''
    runHook preBuild
    make -C tools all \
      CC="x86_64-w64-mingw32-gcc -L${pkgsCross.mingwW64.windows.mcfgthreads}/lib"
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/wine-3dsmax $out/bin
    cp -a docs patches scripts tools LICENSE README.md $out/share/wine-3dsmax/

    mkdir -p $out/share/wine-3dsmax/dxvk/{x64,x86}
    cp -L ${dxvk.bin}/x64/*.dll $out/share/wine-3dsmax/dxvk/x64/
    cp -L ${dxvk.bin}/x32/*.dll $out/share/wine-3dsmax/dxvk/x86/
    install -m644 ${monoMsi} $out/share/wine-3dsmax/wine-mono-11.3.0-x86.msi
    install -m755 ${./setup-runtimes.sh} $out/share/wine-3dsmax/scripts/setup-runtimes.sh
    patchShebangs $out/share/wine-3dsmax/scripts/setup-runtimes.sh

    install -m755 ${./wine-3dsmax.sh} $out/bin/wine-3dsmax
    patchShebangs $out/bin/wine-3dsmax
    wrapProgram $out/bin/wine-3dsmax \
      --set MAX_REPO "$out/share/wine-3dsmax" \
      --prefix PATH : "${lib.makeBinPath runtimeTools}"

    # 补丁 wine 单独可调用；加前缀是为了避开 home.packages 里系统 wine 的同名 bin/wine 冲突，
    # PATH 前置让 wineserver/winepath 等配套工具来自同一次构建。
    # 与 env.sh 同默认 prefix，避免误用系统 ~/.wine 造成版本混用；
    # --set-default 会把值引号化让 $HOME 不展开，故用 --run 在运行时展开且允许外部覆盖。
    for exe in ${patchedWine}/bin/*; do
      name=$(basename "$exe")
      makeWrapper "$exe" "$out/bin/wine-3dsmax-$name" \
        --prefix PATH : "${patchedWine}/bin" \
        --run 'export WINEPREFIX="''${WINEPREFIX:-$HOME/.wine-3dsmax}"' \
        --run 'export WINEDEBUG="''${WINEDEBUG:-${defaultWineDebug}}"'
    done
    runHook postInstall
  '';

  # 需要原生命令名时单独取用：nix shell '.#wine-3dsmax.patchedWine' 里就是 wine/winepath 原名。
  passthru = {
    inherit patchedWine;
  };

  meta = with lib; {
    description = "Autodesk 3ds Max 2027 的补丁版 Wine 11.0 与安装/启动脚本";
    homepage = "https://github.com/cl0nazepamm/3dsmax-wine";
    license = with licenses; [
      mit
      lgpl21Plus
      zlibLibpng
    ];
    mainProgram = "wine-3dsmax";
    platforms = [ "x86_64-linux" ];
  };
}
