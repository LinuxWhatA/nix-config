{
  flake,
  lib,
  ...
}:

{
  # pkgs 的构造参数来自 flake.config.pkgsArgs（与 flake 侧共用同一份，勿在此另写）
  nixpkgs = flake.config.pkgsArgs;

  nix = {
    channel.enable = false;

    settings = {
      trusted-users = [
        "root"
        "@wheel"
      ];
      allowed-users = [
        "root"
        "@users"
      ];
      auto-optimise-store = lib.mkDefault true;
      experimental-features = [
        "flakes"
        "nix-command"
        "ca-derivations"
        "configurable-impure-env"
      ];
      impure-env = [
        "http_proxy"
        "https_proxy"
      ];
      warn-dirty = false;

      # GC 时保留当前系统构建闭包（drv 及其所有输入输出，含 FOD 与编译器），
      # 防止 gnulib/gcc 等被回收后从网络重新下载。
      keep-outputs = true;

      # mkDefault 赢不过 nixpkgs 的 mkAfter 默认值，故 mkForce
      # 列表与 flake.nix 的 nixConfig 共用同一份（数据在 config.nix），避免两处漂移
      substituters = lib.mkForce flake.config.nixSubstituters;
    };
  };
}
