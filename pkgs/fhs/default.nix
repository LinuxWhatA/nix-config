{
  pkgs ? import <nixpkgs> { },
}:

let
  base = pkgs.appimageTools.defaultFhsEnvArgs;
in
pkgs.buildFHSEnv (
  base
  // {
    name = "fhs";
    targetPkgs = pkgs: with pkgs; [ icu ] ++ (base.targetPkgs pkgs);
    profile = ''
      export IN_NIX_SHELL=impure
      export LD_LIBRARY_PATH="/run/opengl-driver/lib:/run/opengl-driver-32/lib";
    '';
    runScript = "zsh";
    extraOutputsToInstall = [ "dev" ];
  }
)
