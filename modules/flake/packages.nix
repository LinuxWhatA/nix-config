# 把 overlays/default.nix 里的包暴露为 flake packages（`nix build .#<包名>`）。
{ self, ... }:
{
  perSystem = { pkgs, lib, ... }: {
    # 按名从已应用 overlay 的 pkgs 取值：不另起 nixpkgs（config 不与 per-system 分叉、少一次求值），
    # 也不对 pkgs 二次跑 overlay（包装类覆盖会叠成两层，产物与系统实际装的不一致）。
    packages = lib.filterAttrs (_: lib.isDerivation) (
      lib.getAttrs (builtins.attrNames (self.overlays.default pkgs pkgs)) pkgs
    );
  };
}
