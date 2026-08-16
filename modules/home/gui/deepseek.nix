{ pkgs, ... }:

let
  v4-flash-godmode = pkgs.fetchFromGitHub {
    owner = "SheberDavid";
    repo = "v4-flash-godmode-opencode-go";
    rev = "cb7fb296ec9df3250ad42e4e6f2868d6566882af";
    hash = "sha256-mjhphGpVnaVTK88CzSx6nSTTvIzNJDVyy7JuemTt+aw=";
  };
in
{
  home.packages = [
    pkgs.deepseek-harness
  ];

  home.file.".dsh/.agent-presets/router-flash" = {
    source = "${v4-flash-godmode}/preset";
    recursive = true;
  };
}
