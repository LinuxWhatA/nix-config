{
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "fcitx5-pinyin-custom-pinyin-dictionary";
  version = "2026-01-01-unstable";

  src = ./CustomPinyinDictionary_Fcitx.dict;
  dontUnpack = true;

  installPhase = ''
    install -Dm444 $src $out/share/fcitx5/pinyin/dictionaries/CustomPinyinDictionary.dict
  '';

  meta = {
    description = "Fcitx5 自建拼音输入法词库，百万常用词汇量";
    homepage = "https://github.com/wuhgit/CustomPinyinDictionary";
    license = lib.licenses.cc-by-sa-40;
    platforms = lib.platforms.all;
  };
}
