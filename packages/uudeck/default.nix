{ stdenvNoCC, lib }:

stdenvNoCC.mkDerivation {
  pname = "uudeck";
  version = "2025-04-12-unstable";

  src = ./uuplugin_monitor.sh;
  unpackPhase = ''
    install -Dm755 $src $out/bin/uudeck
  '';

  meta = {
    description = "网易UU加速器插件监控脚本，自动下载、校验并启动 uuplugin";
    homepage = "https://uu.163.com";
    platforms = lib.platforms.linux;
  };
}
