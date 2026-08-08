{
  lib,
  pkgs,
  python3,
}:

let
  # 复用 AppImage 默认 FHS 环境的目标包清单
  # https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/appimage/default.nix
  pythonldlibpath = lib.makeLibraryPath (pkgs.appimageTools.defaultFhsEnvArgs.targetPkgs pkgs);

  pip = pkgs.writeShellScriptBin "pip" ''
    set -e
    pip=~/.venv/bin/pip3
    if [ ! -f $pip ]; then
      python3 -m venv ~/.venv --copies
      $pip config set global.index-url https://mirrors.cernet.edu.cn/pypi/web/simple
    fi
    exec $pip $@
  '';
in

pkgs.symlinkJoin {
  name = "python";
  paths = [
    python3
    pip
  ];
  buildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    wrapProgram "$out/bin/python3" --prefix LD_LIBRARY_PATH : "${pythonldlibpath}"
  '';
}
