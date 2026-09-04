{
  config,
  flake,
  pkgs,
  ...
}:
{
  programs.niri.enable = true;

  security.polkit.enable = true; # polkit

  services = {
    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${config.programs.niri.package}/bin/niri-session";
          user = flake.config.me.username;
        };
      };
    };
    upower.enable = true;
    gnome.gnome-keyring.enable = true;
    power-profiles-daemon.enable = true;
  };

  # 额外追加 kde portal 以支持 Dolphin 等 KDE 应用
  xdg.portal.extraPortals = with pkgs; [ kdePackages.xdg-desktop-portal-kde ];

  home-manager.users.${flake.config.me.username} = {
    imports = [
      flake.inputs.noctalia.homeModules.default
    ];

    programs.noctalia = {
      enable = true;
      systemd.enable = true;
      settings = {
        theme = {
          mode = "dark";
          source = "builtin";
          builtin = "Catppuccin";
        };
      };
    };

    wayland.windowManager.niri = {
      enable = true;
      # 引入上游默认配置，过滤掉 waybar 启动项，其余快捷键/布局沿用默认
      extraConfigEarly =
        let
          filtered = pkgs.runCommand "niri-default-filtered.kdl" { } ''
            grep -v 'spawn-at-startup "waybar"' ${pkgs.niri.doc}/share/doc/niri/default-config.kdl > $out
          '';
        in
        ''include "${filtered}"'';
      settings = {
        binds = {
          # 覆盖/补充：终端、文件管理器、noctalia 相关（其余沿用 include 的默认配置）
          "Mod+T" = {
            _props.hotkey-overlay-title = "打开终端";
            spawn = [ "xdg-terminal-exec" ];
          };
          "Mod+E" = {
            _props.hotkey-overlay-title = "打开文件管理器";
            spawn = [
              "xdg-open"
              "."
            ];
          };
          "Mod+D" = {
            _props.hotkey-overlay-title = "启动器: noctalia";
            spawn = [
              "noctalia"
              "msg"
              "panel-toggle"
              "launcher"
            ];
          };
          "Mod+V" = {
            _props.hotkey-overlay-title = "剪贴板: noctalia";
            spawn = [
              "noctalia"
              "msg"
              "panel-toggle"
              "clipboard"
            ];
          };
          "Mod+A" = {
            _props.hotkey-overlay-title = "控制中心: noctalia";
            spawn = [
              "noctalia"
              "msg"
              "panel-toggle"
              "control-center"
            ];
          };
          "Mod+L" = {
            _props.hotkey-overlay-title = "锁屏: noctalia";
            spawn = [
              "noctalia"
              "msg"
              "session"
              "lock"
            ];
          };
          # 原 Mod+V 默认是 toggle-window-floating，挪到 Mod+Ctrl+V
          "Mod+Ctrl+V" = {
            _props.hotkey-overlay-title = "切换浮动";
            toggle-window-floating = { };
          };
          # 补齐默认未覆盖的多媒体/亮度（走 noctalia）
          "XF86AudioRaiseVolume" = {
            _props.allow-when-locked = true;
            spawn = [
              "sh"
              "-c"
              "noctalia msg volume-up"
            ];
          };
          "XF86AudioLowerVolume" = {
            _props.allow-when-locked = true;
            spawn = [
              "sh"
              "-c"
              "noctalia msg volume-down"
            ];
          };
          "XF86AudioMute" = {
            _props.allow-when-locked = true;
            spawn = [
              "sh"
              "-c"
              "noctalia msg volume-mute"
            ];
          };
          "XF86MonBrightnessUp" = {
            _props.allow-when-locked = true;
            spawn = [
              "sh"
              "-c"
              "noctalia msg brightness-up"
            ];
          };
          "XF86MonBrightnessDown" = {
            _props.allow-when-locked = true;
            spawn = [
              "sh"
              "-c"
              "noctalia msg brightness-down"
            ];
          };
        };
      };
    };

    # polkit 认证代理：niri 会话由 systemd 托管，交由用户服务随图形会话启停；
    # 不可用 spawn-at-startup——它的列表元素会被当作 argv 拆分，整串命令会变成单个可执行文件
    systemd.user.services.polkit-kde-authentication-agent-1 = {
      Unit = {
        Description = "KDE polkit authentication agent";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };
      Service = {
        ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    home.packages = with pkgs; [
      xwayland-satellite # xwayland support
    ];

    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "inode/directory" = [ "org.kde.dolphin.desktop" ];
      };
    };
  };

  environment.systemPackages = with pkgs; [
    kdePackages.konsole
    kdePackages.dolphin
    kdePackages.qtsvg
    kdePackages.kio
    kdePackages.kio-fuse
    kdePackages.kio-extras
    kdePackages.polkit-kde-agent-1
  ];
  # 不再安装 XDG applications.menu：niri/noctalia 直接消费 .desktop 文件，
  # 仅为一份菜单把整套 plasma-workspace 拉进系统闭包并不划算
}
