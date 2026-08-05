# Top-level flake glue to get our configuration working
{ inputs, self, ... }:

{
  imports = [
    inputs.nixos-unified.flakeModules.default
    inputs.nixos-unified.flakeModules.autoWire
  ];

  systems = [ "x86_64-linux" ];

  perSystem = { system, ... }:
    let
      # 把 packages/ 下的自定义包挂进 nixpkgs
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = builtins.attrValues self.overlays;
        config.allowUnfree = true;
      };
    in
    {
      _module.args.pkgs = pkgs;

      # For 'nix fmt'
      formatter = pkgs.nixfmt;
    };
}
