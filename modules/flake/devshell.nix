{
  perSystem = { pkgs, ... }: {
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
