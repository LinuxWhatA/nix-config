# 自动将 overlays/default.nix 中定义的全部包暴露为 flake packages output，
# 使其可通过 `nix build .#<包名>` 构建。
#
# 注意：覆盖 autowire.nix 中 perSystem.packages 的普通定义，必须用 mkForce；
# mkDefault 优先级低于普通定义，会整个失效。
{ self, ... }:
{
  perSystem = { pkgs, lib, ... }: {
    packages = lib.mkForce (
      lib.filterAttrs (name: value: lib.isDerivation value) (self.overlays.default pkgs pkgs)
    );
  };
}
