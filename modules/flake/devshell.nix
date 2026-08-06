{
  perSystem = { pkgs, ... }: {
    devShells.default = pkgs.mkShell {
      name = "nix-config-shell";
      meta.description = "Shell environment for modifying this Nix configuration";
      packages = with pkgs; [
        just
        nixd
      ];
    };
  };
}
