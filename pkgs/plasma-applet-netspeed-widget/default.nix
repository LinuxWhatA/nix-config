{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation rec {
  pname = "plasma-applet-netspeed-widget";
  version = "3.1";

  src = fetchFromGitHub {
    owner = "dfaust";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-lP2wenbrghMwrRl13trTidZDz+PllyQXQT3n9n3hzrg=";
  };

  installPhase = ''
    mkdir -p $out/share/plasma/plasmoids/org.kde.netspeedWidget
    cp -r package/* $out/share/plasma/plasmoids/org.kde.netspeedWidget
  '';

  meta = {
    description = "Plasma 5 and 6 widget that displays the currently used network bandwidth.";
    homepage = "https://github.com/dfaust/plasma-applet-netspeed-widget";
    license = lib.licenses.gpl2;
    platforms = lib.platforms.linux;
  };
}
