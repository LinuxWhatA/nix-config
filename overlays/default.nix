{ flake, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
  packages = self + /packages;
in
self: super:
let
  # Auto-import all packages from the packages directory
  # TODO: Upstream this to nixos0-unified?
  entries = builtins.readDir packages;

  # Convert directory entries to package definitions
  makePackage =
    name: type:
    let
      # Remove .nix extension for package name
      pkgName =
        if type == "regular" && builtins.match ".*\\.nix$" name != null then
          builtins.replaceStrings [ ".nix" ] [ "" ] name
        else
          name;
    in
    {
      name = pkgName;
      value = self.callPackage (packages + "/${name}") { };
    };

  # Import everything in packages directory
  packageOverlays = builtins.listToAttrs (
    builtins.attrValues (builtins.mapAttrs makePackage entries)
  );
in
packageOverlays
// {
  wechat = super.wechat.override {
    fetchurl =
      { ... }:
      super.fetchurl {
        url = "file://${flake.inputs.wechat}";
        hash = "sha256-RX26ArkbAxzdRBLu4HT7v/udnQax5Q/Bgi00hw4RSZA=";
      };
  };
  nix-alien = flake.inputs.nix-alien.packages.x86_64-linux.nix-alien;
  proton-run = super.writeShellScriptBin "proton-run" ''
    export PROTONPATH="${super.pkgs.proton-ge-bin.steamcompattool}"
    exec ${super.pkgs.umu-launcher}/bin/umu-run "$@"
  '';
  dwproton-run = super.writeShellScriptBin "dwproton-run" ''
    export PROTONPATH="${super.pkgs.dwproton-bin.steamcompattool}"
    exec ${super.pkgs.umu-launcher}/bin/umu-run "$@"
  '';
  motrix-next = super.pkgs.symlinkJoin {
    name = super.motrix-next.name;
    paths = [ super.motrix-next ];
    postBuild = ''
      for f in $out/share/applications/*.desktop; do
        sed 's/^Categories=/Categories=Network;/' "$f" > "$f.bak"
        mv "$f.bak" "$f"
      done
    '';
  };
  wpsoffice-cn = super.pkgs.symlinkJoin {
    name = super.wpsoffice-cn.name;
    paths = [ super.wpsoffice-cn ];
    postBuild = ''
      for f in $out/share/applications/*.desktop; do
        sed 's/^Categories=/Categories=Office;/' "$f" > "$f.bak"
        mv "$f.bak" "$f"
      done
    '';
  };
}
