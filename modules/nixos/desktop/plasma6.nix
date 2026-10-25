{
  config,
  flake,
  pkgs,
  ...
}:

{
  services = {
    displayManager.sddm = {
      enable = true;
      enableHidpi = true;
    };
    # 免密自动登录走通用选项：Autologin 由 sddm 模块生成，会话名跟随 plasma6 的
    # defaultSession，换 DM 或改会话名都不必再动这里
    displayManager.autoLogin = {
      enable = true;
      user = "${flake.config.me.username}";
    };
    desktopManager.plasma6.enable = true;

    # Secret 门户与 keyring：Plasma 原生栈由 kwallet 承接（plasma-workspace 的
    # kde-portals.conf 经 configPackages 下发），不重复声明；gnome-keyring 作兼容层，
    # 供直接查 org.freedesktop.secret 的应用使用
    gnome.gnome-keyring.enable = true;
  };

  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    kate
    krdp
    elisa
    okular
    khelpcenter
    baloo-widgets
    plasma-browser-integration
  ];
  programs.kdeconnect.enable = true;

  home-manager.users.${flake.config.me.username} = {
    imports = [ flake.inputs.plasma-manager.homeModules.plasma-manager ];
    home.packages = [ pkgs.plasma-applet-netspeed-widget ];

    programs.plasma = {
      enable = true;
      panels = [
        {
          location = "bottom";
          widgets = [
            {
              kickoff = {
                sortAlphabetically = true; # 按字母排序
                icon = "nix-snowflake";
              };
            }
            {
              iconTasks.launchers = [
                # 图标任务管理器
                "applications:org.kde.dolphin.desktop"
                "applications:kitty.desktop"
                "applications:firefox.desktop"
                "applications:code.desktop"
              ];
            }
            "org.kde.plasma.marginsseparator" # 边距分隔线
            {
              name = "org.kde.netspeedWidget";
              config.General.fontSize = 120;
            }
            "org.kde.plasma.systemtray" # 系统托盘
            "org.kde.plasma.digitalclock" # 数字时钟
          ];
        }
      ];
      shortcuts = {
        "services/systemsettings.desktop"."_launch" = [
          "Meta+I"
          "Tools"
        ];
      };
      configFile = {
        "kscreenlockerrc"."Daemon"."Autolock" = false; # 自动锁屏
        "kscreenlockerrc"."Daemon"."LockOnResume" = false; # 唤醒后锁屏
        "kscreenlockerrc"."Daemon"."Timeout" = 0; # 锁屏超时
        "kcminputrc"."Keyboard"."NumLock" = 0; # 开启数字键盘
        "klipperrc"."General"."IgnoreImages" = false; # 启用剪切板图片
        "klipperrc"."General"."MaxClipItems" = 200; # 剪切板最大条目数
        # 社区推荐 launcher 变体：fcitx5 自带同名 org.fcitx.Fcitx5 D-Bus 激活服务
        "kwinrc"."Wayland"."InputMethod" =
          "${config.i18n.inputMethod.package}/share/applications/fcitx5-wayland-launcher.desktop";
        "kwinrc"."Plugins"."wobblywindowsEnabled" = true; # 窗口惯性晃动特效
        "kwinrc"."Plugins"."squashEnabled" = false; # 关闭（收缩）最小化动画
        "kwinrc"."Plugins"."magiclampEnabled" = true; # 开启（神灯）最小化动画
        "krunnerrc"."Plugins"."baloosearchEnabled" = false; # 关闭文件索引
        "baloofilerc"."Basic Settings"."Indexing-Enabled" = false;
      };
    };
  };
}
