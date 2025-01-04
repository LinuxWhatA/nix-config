{ pkgs, inputs, ... }:

{
  imports = [
    ../common
    inputs.plasma-manager.homeManagerModules.plasma-manager
  ];

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
      "kcminputrc"."Keyboard"."NumLock" = 0;
      "kded5rc"."Module-printmanager"."autoload" = false;
      "kscreenlockerrc"."Daemon"."Autolock" = false;
      "kscreenlockerrc"."Daemon"."LockOnResume" = false;
      "kwinrc"."Wayland"."InputMethod" =
        "/run/current-system/sw/share/applications/org.fcitx.Fcitx5.desktop";
    };
  };
}
