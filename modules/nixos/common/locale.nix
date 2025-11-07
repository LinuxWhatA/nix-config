{ lib, pkgs, ... }:

{
  i18n = {
    defaultLocale = "zh_CN.UTF-8";
    extraLocaleSettings = {
      LC_ALL = "zh_CN.UTF-8";
    };

    inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        waylandFrontend = true;
        addons = with pkgs; [
          fcitx5-gtk
          fcitx5-pinyin-zhwiki
          fcitx5-pinyin-moegirl
          fcitx5-material-color
          qt6Packages.fcitx5-chinese-addons
        ];
        settings.addons = {
          pinyin.globalSection.CloudPinyinEnabled = "True";
          cloudpinyin.globalSection.Backend = "Baidu";
          classicui.globalSection.Theme = "Material-Color-blue";
          classicui.globalSection.DarkTheme = "Material-Color-blue";
          classicui.globalSection.UseDarkTheme = "True";
        };
      };
    };
  };

  time.timeZone = lib.mkDefault "Asia/Shanghai";
}
