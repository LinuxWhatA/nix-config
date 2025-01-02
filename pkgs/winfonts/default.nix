{
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "winfonts";
  version = "1.0";

  src = ./fonts;
  installPhase = "install -Dm644 * -t $out/share/fonts/truetype";

  meta = with lib; {
    description = "fonts from Microsoft Windows 11 For Simplified Chinese";
    homepage = "https://learn.microsoft.com/zh-cn/typography/font-list";
    license = licenses.unfree;
    platforms = platforms.all;
  };
}
