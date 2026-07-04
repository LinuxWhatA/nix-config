{
  flake,
  pkgs,
  lib,
  ...
}:
{
  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.autoSuspend = false;
  services.gnome.games.enable = false;

  environment.gnome.excludePackages = with pkgs; [
    orca # 屏幕阅读器
    yelp # 帮助
    geary # 邮件
    evince # 文档查看器
    epiphany # 浏览器
    simple-scan # 打印
    gnome-tour # 导览
    gnome-maps # 地图
    gnome-music # 音乐
    gnome-weather # 天气
    gnome-contacts # 联系人
  ];

  environment.variables = {
    XMODIFIERS = "@im=fcitx";
    QT_IM_MODULE = "fcitx";
  };

  # kde connect 端口
  networking.firewall = rec {
    allowedTCPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
    allowedUDPPortRanges = allowedTCPPortRanges;
  };

  home-manager.users.${flake.config.me.username} = {
    programs.gnome-shell = {
      enable = true;
      extensions = map (pkg: { package = pkg; }) [
        pkgs.gnomeExtensions.vitals # 系统监控
        pkgs.gnomeExtensions.kimpanel # Fcitx 用户界面
        pkgs.gnomeExtensions.gsconnect
        pkgs.gnomeExtensions.dash-to-dock
        pkgs.gnomeExtensions.appindicator # 托盘图标
        pkgs.gnomeExtensions.blur-my-shell # 美化
        pkgs.gnomeExtensions.clipboard-indicator # 剪贴板
      ];
    };

    dconf = {
      enable = true;
      settings = {
        "org/gnome/shell" = {
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
  };
}
