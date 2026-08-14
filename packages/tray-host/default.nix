# WSLg tray bridge — Windows 侧
#
# microsoft/wslg#158: 在 Windows 任务栏显示 Linux 托盘图标。
# 打包 Windows Python + 依赖，拷到 Windows 上直接运行。
#
# 注意：
#   - pystray/six 是纯 Python，复用 nix 构建产物；
#   - Pillow 必须用 PyPI 的 win_amd64 wheel（nix 编出来是 Linux .so），
#     wheel 本身是 zip，直接解压进 site-packages；
#   - embeddable python 的 ._pth 默认注释掉了 `import site`，需取消注释。
#
# 用法：
#   nix build .#tray-host
#   python.exe main.py [--host 127.0.0.1] [--port 17632]
#
{
  lib,
  stdenv,
  fetchurl,
  python3,
  unzip,
}:
let
  src = lib.cleanSource ./src;

  python-embed = fetchurl {
    url = "https://www.python.org/ftp/python/${python3.version}/python-${python3.version}-embed-amd64.zip";
    hash = "sha256-35AehKiW/x7nIK0DN34MjYwiRP2nmAiu6v9jFt8ct1w=";
  };

  pillow-win = fetchurl {
    url = "https://files.pythonhosted.org/packages/f1/e0/492879f69d94f91f60fc8cd05ba03650e9520afebb2fb7aa12777d7c7f38/pillow-12.3.0-cp314-cp314-win_amd64.whl";
    hash = "sha256-/a/JzOQCd+D3oP6rzg7lDdL6GADzs4AV5RKWtegUBI0=";
  };
in
stdenv.mkDerivation {
  pname = "tray-host";
  version = "0.1.0";

  dontUnpack = true;
  dontPatchShebangs = true;
  nativeBuildInputs = [ unzip ];

  installPhase = ''
    mkdir -p $out/python/Lib/site-packages
    unzip ${python-embed} -d $out/python
    chmod +x $out/python/python.exe
    unzip ${pillow-win} -d $out/python/Lib/site-packages
    cp -r ${python3.pkgs.pystray}/lib/python*/site-packages/* $out/python/Lib/site-packages/
    cp -r ${python3.pkgs.six}/lib/python*/site-packages/* $out/python/Lib/site-packages/
    cp -r ${src}/main.py $out/python/main.py
    sed -i 's/^# *import site/import site/' $out/python/python3*._pth
    mkdir -p $out/bin
    cat > $out/bin/tray-host <<'EOF'
      #!/usr/bin/env bash
      cd "$(dirname "$(readlink -f "$0")")/../python"
      exec ./python.exe main.py "$@"
    EOF
    chmod +x $out/bin/tray-host
    cat > $out/bin/tray-host.cmd <<'EOF'
      @echo off
      cd /d "%~dp0..\python"
      python.exe main.py %*
    EOF
  '';

  meta = with lib; {
    description = "WSLg tray bridge - Windows side";
    homepage = "https://github.com/microsoft/wslg/issues/158";
    license = licenses.mit;
  };
}
