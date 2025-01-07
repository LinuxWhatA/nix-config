{
  pkgs ? import <nixpkgs> { },
}:

pkgs.buildFHSEnv {
  name = "fhs";
  includeClosures = true;
  targetPkgs =
    pkgs:
    with pkgs;
    [
      icu
      zenity
    ]
    ++ pkgs.appimageTools.defaultFhsEnvArgs.targetPkgs pkgs;
  profile = ''
    export IN_NIX_SHELL=impure
    export LD_LIBRARY_PATH="/run/opengl-driver/lib:/run/opengl-driver-32/lib"
  '';
  runScript = pkgs.writeShellScript "fhs" "exec $@";
}
