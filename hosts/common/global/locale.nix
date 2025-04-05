{ lib, pkgs, ... }:

{
  i18n = {
    defaultLocale = "zh_CN.UTF-8";
    supportedLocales = [
      "zh_CN.UTF-8/UTF-8"
    ];

    inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        waylandFrontend = true;
        addons = with pkgs; [
          fcitx5-gtk
          fcitx5-nord
          fcitx5-pinyin-zhwiki
          fcitx5-chinese-addons
        ];
        settings.addons = {
          pinyin.globalSection.CloudPinyinEnabled = "True";
          cloudpinyin.globalSection.Backend = "Baidu";
          classicui.globalSection.Theme = "Nord-Light";
          classicui.globalSection.DarkTheme = "Nord-Dark";
          classicui.globalSection.UseDarkTheme = "True";
        };
      };
    };
  };

  time.timeZone = lib.mkDefault "Asia/Shanghai";
}
