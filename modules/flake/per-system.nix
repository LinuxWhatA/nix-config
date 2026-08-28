{ inputs, self, ... }:
{
  perSystem =
    { system, ... }:
    let
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = builtins.attrValues self.overlays;
        config.allowUnfree = true;
      };
    in
    {
      _module.args.pkgs = pkgs;
      formatter = pkgs.nixfmt;
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
