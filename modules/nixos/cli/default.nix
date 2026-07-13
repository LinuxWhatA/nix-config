{ flake, ... }:
{
  imports =
    with builtins;
    map (fn: ./${fn}) (filter (fn: fn != "default.nix") (attrNames (readDir ./.)));

  environment.etc."nixos".source = flake.inputs.self;
}
