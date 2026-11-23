# 自动注入 packages/ + 自定义覆盖
{ flake, ... }:
let
  inherit (flake) inputs;
in
final: prev:
let

  # category 形如 "Network;FileTransfer"（分号分隔的多分类，与上游 deb/rpm 模板一致）：
  # 必须引号化后再插值，否则 shell 会在分号处断句，desktop-file-edit 收不到文件参数
  withCategory =
    category: pkg:
    prev.symlinkJoin {
      inherit (pkg) name meta;
      paths = [ pkg ];
      nativeBuildInputs = [ prev.desktop-file-utils ];
      postBuild = ''
        for f in "$out"/share/applications/*.desktop; do
          desktop-file-edit --add-category=${prev.lib.escapeShellArg category} "$f"
        done
      '';
    };

  # desktop 条目的 Exec 写的是命令名（按 PATH 解析），所以在 bin 这层包一次，终端敲 wps 与从菜单
  # 启动就是同一条路，不必再给 desktop 的 Exec 加前缀。
  withCgroupRun =
    {
      extraRunArgs ? [ ],
    }:
    pkg:
    prev.symlinkJoin {
      inherit (pkg) name meta;
      paths = [ pkg ];
      nativeBuildInputs = [ prev.makeWrapper ];
      postBuild = ''
        for entry in ${pkg}/bin/*; do
          wrapped="$out/bin/$(basename "$entry")"
          rm "$wrapped"
          # extraRunArgs 是 cgroup-run 的前置参数，原样转发给 systemd-run（见下 cgroupRun）
          makeWrapper ${cgroupRun}/bin/cgroup-run "$wrapped" \
            ${
              prev.lib.concatMapStringsSep " " (a: "--add-flags ${prev.lib.escapeShellArg a}") extraRunArgs
            } \
            --add-flags "$entry"
        done
      '';
    };

  mkProtonRun =
    name: compat:
    prev.writeShellScriptBin name ''
      export PROTONPATH="${compat}"
      exec ${prev.umu-launcher}/bin/umu-run "$@"
    '';

  # 命令跑在 systemd --user 的 transient service 里：主进程一退出单元即停止，KillMode=control-group
  # 按 cgroup 连坐收走残留（先 SIGTERM 超时再 SIGKILL），不看应用内部结构、也不要求它配合信号——
  # 这就是「关窗后留一堆孤儿」的黑箱应用的解法。用法：`cgroup-run <命令> [参数…]`。
  #
  # --pipe 与 --pty 同时给，由 systemd-run 按 stdio 自选（有 TTY 走 --pty，否则 --pipe）；--pty 隐含
  # 同步等待，--wait 给 --pipe 分支补上；TimeoutStopSec=5 是因为默认 90s 会吊住终端。
  # 前置 --setenv=NAME=VALUE 转给 systemd-run（transient unit 不继承调用者环境），其余参数是命令。
  cgroupRun = prev.writeShellScriptBin "cgroup-run" ''
    if [ "$#" -eq 0 ]; then
      echo "用法: cgroup-run <命令> [参数…]" >&2
      exit 2
    fi
    setenvs=()
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --setenv=*)
          setenvs+=("$1")
          shift
          ;;
        *)
          break
          ;;
      esac
    done
    exec ${prev.systemd}/bin/systemd-run \
      --user \
      --quiet \
      --collect \
      --service-type=exec \
      --wait \
      --pipe \
      --pty \
      --property=KillMode=control-group \
      --property=TimeoutStopSec=5 \
      --same-dir \
      "''${setenvs[@]}" \
      -- "$@"
  '';

  # setup.sh 从 apps/* 扫描已装应用，改动必须在 postPatch 落地才进 $out/src；提为 let 绑定是因为
  # launcher 要与 final.winapps 同一次构建。sed 让产物里的启动路径走 PATH，store path 变化不失效。
  winapps-patched = inputs.winapps.packages.x86_64-linux.winapps.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      sed -i 's|/nix/store/[^ ]*/bin/winapps |winapps |g' setup.sh
    '';
  });
in
(builtins.listToAttrs (
  map (name: {
    inherit name;
    value = prev.callPackage ../packages/${name} { };
  }) (builtins.attrNames (builtins.readDir ../packages))
))
// {
  fcitx5-wetypex = inputs.wetypex.packages.x86_64-linux.default;

  # 目录名带连字符，callPackage 遍历给出的是 merge-json；对外仍用驼峰别名
  mergeJson = final.merge-json;
  inherit cgroupRun;

  # 取 flake 产物而非它的 overlay：让它用自带 flake.lock 的 nixpkgs pin 构建，
  # 我们顶到上游测试腐化时不会连带它（详见 flake.nix 里该 input 的注释）
  nix-alien = inputs.nix-alien.packages.x86_64-linux.nix-alien;

  # amdgpu gfxhub page fault 缓解：GPU 进程改走 radv(Vulkan) 而非 radeonsi(GL)；argv.json 白名单不含
  # use-angle，只能在 wrapper 注入。会话 XDG_DATA_DIRS 不含 driver link，自带 loader 找不到 ICD 会报
  # VK_ERROR_INCOMPATIBLE_DRIVER；指 /run/opengl-driver/share 让它自行枚举。用 symlinkJoin 以免重编译。
  vscode = prev.symlinkJoin {
    inherit (prev.vscode) name version meta;
    paths = [ prev.vscode ];
    nativeBuildInputs = [ prev.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/code" \
        --add-flags "--use-angle=vulkan" \
        --prefix XDG_DATA_DIRS : "/run/opengl-driver/share"
    '';
  };

  proton-run = mkProtonRun "proton-run" prev.proton-ge-bin.steamcompattool;
  dwproton-run = mkProtonRun "dwproton-run" prev.dwproton-bin.steamcompattool;

  # uur 把 wine 写死为 wineWow64Packages.stable，而 UU 远程依赖的补丁多在 staging。package.nix 只取
  # 该集合的 .stable，故传一个 stable 指向 staging 的集合即可换掉它；上游若改用其它成员会直接报错。
  uur = inputs.uur.packages.x86_64-linux.uur.override {
    wineWow64Packages = {
      stable = final.wineWow64Packages.staging;
    };
  };

  winapps = winapps-patched;

  # 传 final.winapps（注入版）：launcher 在 ~/.local/bin 里以 '^winapps ' 匹配应用条目，
  # 该形态由注入版 setup.sh 生成；换 prev.winapps 则条目是 store 路径，launcher 扫不到
  winapps-launcher = prev.callPackage ../packages/winapps-launcher {
    inherit (final) winapps;
  };

  # WPS 捆绑旧 Qt 只有 fcitx4 插件且只能跑 XWayland，全局又不导出 QT_IM_MODULE（Wayland Qt
  # 走 text-input），故输入法失效。经 --setenv 只给它注入 QT_IM_MODULE=fcitx（fcitx5 兼容
  # fcitx4 D-Bus 协议）；用 --setenv 而非环境变量，因 systemd-run 的 unit 不继承调用者环境。
  # 参考 fcitx/fcitx5#83、#1231。
  wpsoffice-cn = prev.lib.pipe prev.wpsoffice-cn [
    (withCgroupRun { extraRunArgs = [ "--setenv=QT_IM_MODULE=fcitx" ]; })
    (withCategory "Office")
  ];
}
