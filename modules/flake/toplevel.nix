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
    };
}
