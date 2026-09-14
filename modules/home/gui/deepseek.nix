{ pkgs, ... }:

let
  deepseek-harness = pkgs.callPackage (pkgs.fetchurl {
    url =
      "https://raw.githubusercontent.com/Dietr1ch/nixpkgs/"
      + "ca9e0fe45089db1b82fb2796d6e4d414225d9a48/pkgs/by-name/de/deepseek-harness/package.nix";
    hash = "sha256-Y6Zau/J7VpxXtlPttJAmyeZq6Vg1qLmQmgVobAt5yCc=";
  }) { };

  v4-flash-godmode = pkgs.fetchFromGitHub {
    owner = "SheberDavid";
    repo = "v4-flash-godmode-opencode-go";
    rev = "cb7fb296ec9df3250ad42e4e6f2868d6566882af";
    hash = "sha256-mjhphGpVnaVTK88CzSx6nSTTvIzNJDVyy7JuemTt+aw=";
  };
in
{
  home.packages = [ deepseek-harness ];

  home.file.".dsh/.agent-presets/router-flash" = {
    source = "${v4-flash-godmode}/preset";
    recursive = true;
  };
}
