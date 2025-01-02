{ lib, pkgs, ... }:

{
  i18n = {
    defaultLocale = lib.mkDefault "zh_CN.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "zh_CN.UTF-8";
      LC_IDENTIFICATION = "zh_CN.UTF-8";
      LC_MEASUREMENT = "zh_CN.UTF-8";
      LC_MONETARY = "zh_CN.UTF-8";
      LC_NAME = "zh_CN.UTF-8";
      LC_NUMERIC = "zh_CN.UTF-8";
      LC_PAPER = "zh_CN.UTF-8";
      LC_TELEPHONE = "zh_CN.UTF-8";
      LC_TIME = "zh_CN.UTF-8";
    };
    supportedLocales = lib.mkDefault [
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
