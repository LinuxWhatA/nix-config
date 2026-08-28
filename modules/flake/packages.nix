# 自动将 overlays/default.nix 中定义的全部包暴露为 flake packages output，
# 使其可通过 `nix build .#<包名>` 构建。
{ self, ... }:
{
  perSystem = { pkgs, lib, ... }: {
    packages = lib.filterAttrs (name: value: lib.isDerivation value) (self.overlays.default pkgs pkgs);
  };
}
