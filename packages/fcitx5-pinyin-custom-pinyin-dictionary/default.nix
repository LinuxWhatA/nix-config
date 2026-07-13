{
  lib,
  fetchurl,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "fcitx5-pinyin-custom-pinyin-dictionary";
  version = "20260101";

  src = fetchurl {
    # url = "https://github.com/wuhgit/CustomPinyinDictionaryreleases/download/assets/CustomPinyinDictionary_Fcitx.dict";
    url = "file://${./CustomPinyinDictionary_Fcitx.dict}";
    hash = "sha256-Y2d7DhvNknbo7u9BVTq1Mr9gYSeFWNnvo2KbDr6INuU=";
  };

  unpackPhase = ''
    install -Dm555 $src $out/share/fcitx5/pinyin/dictionaries/CustomPinyinDictionary.dict
  '';

  meta = {
    description = "Fcitx5 自建拼音输入法词库，百万常用词汇量";
    homepage = "https://github.com/wuhgit/CustomPinyinDictionary";
    license = lib.licenses.free;
    platforms = lib.platforms.all;
  };
}
