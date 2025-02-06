{
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "winfonts";
  version = "1.0";

  src = ./fonts;
  installPhase = "install -Dm644 * -t $out/share/fonts/truetype";

  meta = {
    description = "fonts from Microsoft Windows 11 For Simplified Chinese";
    homepage = "https://learn.microsoft.com/zh-cn/typography/font-list";
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
  };
}
