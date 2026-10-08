{
  buildFHSEnv,
  appimageTools,
  zsh,
  icu,
  libepoxy,
  webkitgtk_4_1,
  libappindicator,
  libayatana-appindicator,
}:

buildFHSEnv {
  name = "fhs";
  includeClosures = true;
  targetPkgs =
    pkgs:
    [
      icu
      libepoxy
      webkitgtk_4_1
      libappindicator
      libayatana-appindicator
    ]
    ++ appimageTools.defaultFhsEnvArgs.targetPkgs pkgs;
  multiPkgs = appimageTools.defaultFhsEnvArgs.multiPkgs;
  profile = ''
    export IN_NIX_SHELL=impure
    # 空段会被链接器当成当前目录：LD_LIBRARY_PATH 未设时上面的写法等于把 CWD 放进搜索路径
    export LD_LIBRARY_PATH="''${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}/run/opengl-driver/lib:/run/opengl-driver-32/lib"
  '';
  runScript = "${zsh}/bin/zsh";
  extraOutputsToInstall = [ "dev" ];
}
