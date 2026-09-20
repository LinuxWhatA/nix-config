# 自动注入 packages/ + 自定义覆盖
{ flake, ... }:
let
  inherit (flake) inputs;
in
final: prev:
let
  inherit ((import (flake.inputs.self + /lib/merge-json.nix) { inherit (prev) pkgs; })) mergeJson;

  withCategory =
    category: pkg:
    prev.symlinkJoin {
      inherit (pkg) name meta;
      paths = [ pkg ];
      nativeBuildInputs = [ prev.desktop-file-utils ];
      postBuild = ''
        for f in "$out"/share/applications/*.desktop; do
          desktop-file-edit --add-category=${category} "$f"
        done
      '';
    };

  # desktop 条目的 Exec 写的是命令名（按 PATH 解析），所以在 bin 这层包一次，终端敲 wps 与从菜单
  # 启动就是同一条路，不必再给 desktop 的 Exec 加前缀。
  withCgroupRun =
    pkg:
    prev.symlinkJoin {
      inherit (pkg) name meta;
      paths = [ pkg ];
      nativeBuildInputs = [ prev.makeWrapper ];
      postBuild = ''
        for entry in ${pkg}/bin/*; do
          wrapped="$out/bin/$(basename "$entry")"
          rm "$wrapped"
          makeWrapper ${cgroupRun}/bin/cgroup-run "$wrapped" --add-flags "$entry"
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
  cgroupRun = prev.writeShellScriptBin "cgroup-run" ''
    if [ "$#" -eq 0 ]; then
      echo "用法: cgroup-run <命令> [参数…]" >&2
      exit 2
    fi
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
  inherit mergeJson cgroupRun;

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

  winapps = winapps-patched;

  # 传 final.winapps（注入版）保证 launcher 的 WINAPPS_PATH 与系统一致；包内另有上游未同步的 VM_NAME 修复
  winapps-launcher = prev.callPackage ../packages/winapps-launcher {
    inherit (final) winapps;
  };

  motrix-next = withCategory "Network" prev.motrix-next;
  wpsoffice-cn = withCategory "Office" (withCgroupRun prev.wpsoffice-cn);

  # 上游 tmpfiles 模板把 hook 目录定在 CMAKE_INSTALL_PREFIX 下，即只读 store 内的路径：建不出来而报错
  # 并以 73 退出，令 systemd-tmpfiles-setup 被判失败（后续规则仍执行，但会掩盖真正的 tmpfiles 问题）。
  # store 内本就放不了 hook 脚本，故删该行；/var/lib/linglong、/run/linglong 等仍由包内其余行创建
  linyaps = prev.linyaps.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      sed -i -e "\|^# Create a directory to place the hook script$|d" \
             -e "\|^d $out/etc/linglong/config\.d |d" "$out/lib/tmpfiles.d/linglong.conf"
    '';
  });
}
