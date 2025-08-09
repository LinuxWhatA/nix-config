{ pkgs, lib, ... }:

{
  imports = [
    ../common
  ];

  home.packages = with pkgs.gnomeExtensions; [
    vitals # 系统监控
    kimpanel # Fcitx 用户界面
    gsconnect
    dash-to-dock
    appindicator # 托盘图标
    blur-my-shell # 美化
    clipboard-indicator # 剪贴板
  ];

  dconf = {
    enable = true;
    settings = {
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = with pkgs.gnomeExtensions; [
          vitals.extensionUuid
          kimpanel.extensionUuid
          gsconnect.extensionUuid
          dash-to-dock.extensionUuid
          appindicator.extensionUuid
          blur-my-shell.extensionUuid
          clipboard-indicator.extensionUuid
        ];
        favorite-apps = [
          "org.gnome.Nautilus.desktop" # 文件管理器
          "org.gnome.Console.desktop"
          "firefox.desktop"
          "code.desktop"
        ];
      };
      "org/gnome/shell/extensions/vitals" = {
        "position-in-panel" = 0;
      };
      "org/gnome/shell/extensions/blur-my-shell" = {
        "dash-to-dock/blur" = false;
        "panel/static-blur" = false;
        "panel/brightness" = 1.0;
      };
      "org/gnome/shell/extensions/dash-to-dock" = {
        show-trash = false;
        running-indicator-style = "DOTS";
        transparency-mode = "DYNAMIC";
        click-action = "minimize-or-previews";
        scroll-action = "switch-workspace";
      };
      "org/gnome/shell/keybindings".toggle-message-tray = [ "<Super>t" ]; # 通知列表快捷键
      "org/gnome/shell/extensions/clipboard-indicator" = {
        toggle-menu = [ "<Super>v" ]; # 剪贴板-快捷键
        cache-size = 50;
        history-size = 150;
      };
      "org/gnome/settings-daemon/plugins/xsettings".overrides = [
        (lib.gvariant.mkDictionaryEntry "Gtk/IMModule" (lib.gvariant.mkVariant "fcitx"))
      ];
      "org/gnome/settings-daemon/plugins/media-keys" = {
        home = [ "<Super>e" ]; # 主目录-快捷键
        control-center = [ "<Super>i" ]; # 设置-快捷键
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        ];
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        name = "Console";
        command = "kgx";
        binding = "<Control><Alt>t"; # 终端-快捷键
      };
      "org/gnome/desktop/wm/keybindings".show-desktop = [ "<Super>d" ]; # 隐藏所有窗口-快捷键
      "org/gnome/desktop/wm/preferences".button-layout = "appmenu:minimize,maximize,close"; # 添加窗口按钮
      "org/gnome/desktop/screensaver".lock-enabled = false; # 关闭自动锁屏
      "org/gnome/settings-daemon/plugins/power".sleep-inactive-ac-type = "nothing"; # 关闭插入电源时自动挂起
    };
  };
}
