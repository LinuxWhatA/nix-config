# overlays/default.nix —— 把 packages/ 下的自定义包注入 nixpkgs
# 新增包 = packages/ 下建目录 + default.nix，目录名即包名，自动注入
{ flake, ... }:

let
  inherit (flake) inputs;
in
final: prev:
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
  proton-run = prev.writeShellScriptBin "proton-run" ''
    export PROTONPATH="${prev.proton-ge-bin.steamcompattool}"
    exec ${prev.umu-launcher}/bin/umu-run "$@"
  '';
  dwproton-run = prev.writeShellScriptBin "dwproton-run" ''
    export PROTONPATH="${prev.dwproton-bin.steamcompattool}"
    exec ${prev.umu-launcher}/bin/umu-run "$@"
  '';

  # 上游包修补（归类到应用菜单）
  motrix-next = prev.symlinkJoin {
    name = prev.motrix-next.name;
    paths = [ prev.motrix-next ];
    postBuild = ''
      for f in $out/share/applications/*.desktop; do
        sed 's/^Categories=/Categories=Network;/' "$f" > "$f.bak"
        mv "$f.bak" "$f"
      done
    '';
  };
  wpsoffice-cn = prev.symlinkJoin {
    name = prev.wpsoffice-cn.name;
    paths = [ prev.wpsoffice-cn ];
    postBuild = ''
      for f in $out/share/applications/*.desktop; do
        sed 's/^Categories=/Categories=Office;/' "$f" > "$f.bak"
        mv "$f.bak" "$f"
      done
    '';
  };
}
