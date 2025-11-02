{
  outputs,
  ...
}:

{
  nix.settings = {
    experimental-features = [
      "flakes"
      "nix-command"
      "ca-derivations"
    ];
    warn-dirty = false;
  };

  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays;
    config = {
      allowUnfree = true;
      allowUnfreePredicate = _: true;
    };
  };
}
