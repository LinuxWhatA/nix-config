{ pkgs, inputs, ... }:

{
  imports = [
    ../common
    inputs.plasma-manager.homeManagerModules.plasma-manager
  ];

  services.kdeconnect.enable = true;

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
              "applications:org.kde.konsole.desktop"
              "applications:firefox.desktop"
              "applications:code-url-handler.desktop"
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
      "kwinrc"."Wayland"."InputMethod" =
        "/run/current-system/sw/share/applications/org.fcitx.Fcitx5.desktop"; # 设置虚拟键盘以支持Fcitx
      "kwinrc"."Plugins"."wobblywindowsEnabled" = true; # 窗口惯性晃动特效
      "kwinrc"."Plugins"."squashEnabled" = false; # 关闭（收缩）最小化动画
      "kwinrc"."Plugins"."magiclampEnabled" = true; # 开启（神灯）最小化动画
    };
  };
}
