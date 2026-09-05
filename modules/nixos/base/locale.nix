{ lib, pkgs, ... }:

{
  # waylandFrontend = true 时 nixpkgs 刻意只导出 XMODIFIERS/QT_PLUGIN_PATH，
  # 不导出 GTK_IM_MODULE/QT_IM_MODULE——原生 Wayland 客户端经 text-input 协议输入，
  # 用不到这两个变量；需要它们的仅剩 XWayland 传统客户端，由各桌面会话按需注入，
  # 故不在此做全局声明，以免污染 tty/SSH 等非图形登录环境。
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
          fcitx5-pinyin-custom-pinyin-dictionary
          fcitx5-material-color
          qt6Packages.fcitx5-chinese-addons
        ];
        settings.addons = {
          pinyin.globalSection.CloudPinyinEnabled = "True";
          cloudpinyin.globalSection.Backend = "Baidu";
          classicui.globalSection = {
            UseDarkTheme = "True";
            Theme = "Material-Color-blue";
            DarkTheme = "Material-Color-blue";
          };
        };
      };
    };
  };

  time.timeZone = lib.mkDefault "Asia/Shanghai";
}
