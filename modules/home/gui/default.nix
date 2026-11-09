let
  exclude = [
    "default.nix"
    "noctalia.nix"
  ];
in
{
  imports = map (fn: ./${fn}) (
    builtins.filter (fn: !builtins.elem fn exclude) (builtins.attrNames (builtins.readDir ./.))
  );
}
