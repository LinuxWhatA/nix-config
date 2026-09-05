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
      inherit (pkg) name;
      paths = [ pkg ];
      postBuild = ''
        if [ -d "$out/share/applications" ]; then
          for f in "$out"/share/applications/*.desktop; do
            [ -f "$f" ] || continue
            # 已含该分类则跳过，避免 Categories=Network;Network; 式重复
            grep -qE "^Categories=(.*;)?${category}(;|$)" "$f" && continue
            sed 's/^Categories=/Categories=${category};/' "$f" > "$f.tmp"
            mv "$f.tmp" "$f"
          done
        fi
      '';
    };

  mkProtonRun =
    name: compat:
    prev.writeShellScriptBin name ''
      export PROTONPATH="${compat}"
      exec ${prev.umu-launcher}/bin/umu-run "$@"
    '';

  # setup.sh 的 waFindInstalled 遍历 $SOURCE_PATH/apps/* 生成 installed.bat，
  # postPatch 在 cp -r ./ $out/src/ 之前执行，新 app 会被一起复制。
  # 提为 let 绑定：launcher 需引用同一构建，且 attrset 内不可自引用。
  winapps-patched = inputs.winapps.packages.x86_64-linux.winapps.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      # desktop 文件与 ~/.local/bin 启动脚本一律使用相对路径 winapps（PATH 解析），
      # 避免 store path 变化后失效；launcher 据此以 '^winapps ' 匹配发现应用
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
  inherit mergeJson;

  nix-alien = inputs.nix-alien.packages.x86_64-linux.nix-alien;

  # amdgpu gfxhub page fault 缓解：Chromium GPU 进程改走 radv(Vulkan) 而非 radeonsi(GL)
  # argv.json 白名单不支持 use-angle 开关，只能在启动 wrapper 里注入
  # VK_ICD_FILENAMES：Chromium 捆绑的 vulkan-loader 找不到 NixOS 的 ICD 路径，
  #   不指定则 ANGLE 报 VK_ERROR_INCOMPATIBLE_DRIVER（-9）导致 GPU 进程退出
  #
  # 使用 symlinkJoin：原始 vscode 从 cache.nixos.org 获取，仅创建符号链接 + wrapProgram，
  # build 开销极小。若改用 overrideAttrs 会创建新的 store path，绕过二进制缓存。
  vscode = prev.symlinkJoin {
    name = "${prev.vscode.name}";
    version = "${prev.vscode.version}";
    paths = [ prev.vscode ];
    meta = prev.vscode.meta;
    buildInputs = [ prev.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/code" \
        --add-flags "--use-angle=vulkan" \
        --set VK_ICD_FILENAMES "/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json" \
        --prefix LD_LIBRARY_PATH : "/run/opengl-driver/lib"
    '';
  };

  proton-run = mkProtonRun "proton-run" prev.proton-ge-bin.steamcompattool;
  dwproton-run = mkProtonRun "dwproton-run" prev.dwproton-bin.steamcompattool;

  winapps = winapps-patched;

  # 本地包定义见 packages/winapps-launcher（含 VM_NAME export 修复，上游 winapps
  # 主仓库捆绑的 launcher 副本未同步该修复）
  # 传入 final.winapps（注入版），保证 launcher 的 WINAPPS_PATH 与系统 winapps 一致
  winapps-launcher = prev.callPackage ../packages/winapps-launcher {
    inherit (final) winapps;
  };

  motrix-next = withCategory "Network" prev.motrix-next;
  wpsoffice-cn = withCategory "Office" prev.wpsoffice-cn;
}
