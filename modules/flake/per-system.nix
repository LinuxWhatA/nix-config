{
  inputs,
  config,
  ...
}:
{
  perSystem =
    { system, ... }:
    let
      # 与系统侧共用同一份构造参数（见 config.pkgsArgs）：两处各写一遍会让 .#pkg
      # 的产物与系统里实际装的分叉
      pkgs = import inputs.nixpkgs ({ inherit system; } // config.pkgsArgs);
    in
    {
      _module.args.pkgs = pkgs;
      # 开发环境
      devShells.default = pkgs.mkShell {
        name = "nix-config-shell";
        meta.description = "Shell environment for modifying this Nix configuration";
        packages = with pkgs; [
          (python3.withPackages (p: [
            (p.python-registry.overridePythonAttrs (old: {
              # nixpkgs 声明版本与上游 METADATA 不一致，跳过元数据检查
              dontCheckPythonMetadata = true;
            }))
          ]))
        ];
      };
    };
}
