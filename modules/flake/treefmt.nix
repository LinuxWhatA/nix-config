# 格式化与静态检查交给工具定：nixfmt 统一风格，statix 抓 mkIf/mkMerge/mkForce 密集处的手误。
# formatter 必须指向 treefmt 而非 nixfmt 本体——裸 nixfmt 无参时去读 stdin 并拒绝，直接当
# formatter 会让 `nix fmt` 报错；treefmt 顺带把两者接进 `nix flake check`。
{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem = {
    treefmt = {
      programs = {
        nixfmt.enable = true;
        statix.enable = true;
        # 不开 deadnix：模块函数的形参常按模块系统惯例写全而未被用到，它会把这类一并报出来。
      };
    };
  };
}
