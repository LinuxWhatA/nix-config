# overlays/default.nix —— 把 packages/ 下的自定义包注入 nixpkgs
# 新增包 = packages/ 下建目录 + default.nix，目录名即包名，自动注入
{ flake, ... }:

let
  inherit (flake) inputs;
in
final: prev:
let
  # 给桌面应用补上 .desktop 的应用菜单归类（简单的上游修补）
  withCategory =
    category: pkg:
    prev.symlinkJoin {
      name = pkg.name;
      paths = [ pkg ];
      postBuild = ''
        for f in $out/share/applications/*.desktop; do
          sed 's/^Categories=/Categories=${category};/' "$f" > "$f.bak"
          mv "$f.bak" "$f"
        done
      '';
    };

  # Steam 兼容层启动脚本：设 PROTONPATH 后交给 umu-run
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
  # 微信 AppImage（hash 随文件更新）
  wechat = prev.wechat.override {
    fetchurl =
      { ... }:
      prev.fetchurl {
        url = "file://${inputs.wechat}";
        hash = "sha256-RX26ArkbAxzdRBLu4HT7v/udnQax5Q/Bgi00hw4RSZA=";
      };
  };

  # 直接来自 flake 输入的包
  nix-alien = inputs.nix-alien.packages.x86_64-linux.nix-alien;

  # Steam 兼容层启动脚本
  proton-run = mkProtonRun "proton-run" prev.proton-ge-bin.steamcompattool;
  dwproton-run = mkProtonRun "dwproton-run" prev.dwproton-bin.steamcompattool;

  # 上游包修补（归类到应用菜单）
  motrix-next = withCategory "Network" prev.motrix-next;
  wpsoffice-cn = withCategory "Office" prev.wpsoffice-cn;
}
