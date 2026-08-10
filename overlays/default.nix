# 自动注入 packages/ + 自定义覆盖
{ flake, ... }:
let
  inherit (flake) inputs;
in
final: prev:
let
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
  wechat = prev.wechat.override {
    fetchurl =
      { ... }:
      prev.fetchurl {
        url = "file://${inputs.wechat}";
        hash = "sha256-RX26ArkbAxzdRBLu4HT7v/udnQax5Q/Bgi00hw4RSZA=";
      };
  };

  nix-alien = inputs.nix-alien.packages.x86_64-linux.nix-alien;

  proton-run = mkProtonRun "proton-run" prev.proton-ge-bin.steamcompattool;
  dwproton-run = mkProtonRun "dwproton-run" prev.dwproton-bin.steamcompattool;

  motrix-next = withCategory "Network" prev.motrix-next;
  wpsoffice-cn = withCategory "Office" prev.wpsoffice-cn;
}
