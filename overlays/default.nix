# 自动注入 packages/ + 自定义覆盖
{ flake, ... }:
let
  inherit (flake) inputs;
in
final: prev:
let
  mergeJson = (import (flake.inputs.self + /lib/merge-json.nix) { inherit (prev) pkgs; }).mergeJson;

  withCategory =
    category: pkg:
    prev.symlinkJoin {
      name = pkg.name;
      paths = [ pkg ];
      postBuild = ''
        if [ -d "$out/share/applications" ]; then
          for f in "$out"/share/applications/*.desktop; do
            [ -f "$f" ] || continue
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
in
(builtins.listToAttrs (
  map (name: {
    inherit name;
    value = prev.callPackage ../packages/${name} { };
  }) (builtins.attrNames (builtins.readDir ../packages))
))
// {
  inherit mergeJson;

  wechat = prev.wechat.override {
    fetchurl =
      { ... }:
      prev.fetchurl {
        url = "file://${inputs.wechat}";
        hash = "sha256-RX26ArkbAxzdRBLu4HT7v/udnQax5Q/Bgi00hw4RSZA=";
      };
  };

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

  motrix-next = withCategory "Network" prev.motrix-next;
  wpsoffice-cn = withCategory "Office" prev.wpsoffice-cn;
}
