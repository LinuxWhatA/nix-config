{
  flake,
  pkgs,
  ...
}:
{
  # labwc 为独立合成器，需自行补齐系统级认证与电源能力
  security.polkit.enable = true;

  services = {
    # greetd 直接拉起 labwc：labwc 无显示管理器集成，需显式指定会话入口
    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.labwc}/bin/labwc";
          user = flake.config.me.username;
        };
      };
    };
    upower.enable = true;
    gnome.gnome-keyring.enable = true;
    power-profiles-daemon.enable = true;
  };

  # 门户后端：录屏/截图仅 wlr 实现，故默认 wlr 优先、其余接口以 * 兜底
  xdg.portal = {
    enable = true;
    wlr.enable = true; # 追加 xdg-desktop-portal-wlr
    # gnome-keyring 后端由 services.gnome.gnome-keyring 自动追加，此处只须补 gtk
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    # config.labwc 一旦设置即整体覆盖 labwc 包自带的 labwc-portals.conf，
    # 需写全以保持相同语义：default=wlr;*、Inhibit=none
    config.labwc = {
      default = [
        "wlr"
        "*"
      ];
      "org.freedesktop.impl.portal.Inhibit" = [ "none" ]; # Inhibit 接口无可复用后端，置 none
      "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ]; # wlr/gtk 都不实现 Secret
    };
  };

  home-manager.users.${flake.config.me.username} = {
    services = {
      # labwc 不提供输出缩放，需外部守护进程在热插拔时维持比例
      kanshi = {
        enable = true;
        settings = [
          {
            profile.name = "default";
            profile.outputs = [
              {
                criteria = "*";
                scale = 1.75;
              }
            ];
          }
        ];
      };
    };

    # Wayland 光标随输出缩放自动放大，基准保持 24 避免二次放大；XWayland 需单独处理
    home.pointerCursor = {
      enable = true;
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
      size = 24;
      gtk.enable = true;
      x11.enable = true;
    };

    wayland.windowManager.labwc = {
      enable = true;
      xwayland.enable = true;
      # environment 文件只覆盖 labwc 直接派生的进程（XWayland、Execute 键绑、autostart）。
      # noctalia（launcher/dock）是 systemd 用户服务，从 launcher 拉起的应用继承的是
      # systemd/D-Bus 用户环境——默认只导入 DISPLAY/WAYLAND_DISPLAY/XDG_CURRENT_DESKTOP 三个，
      # 输入法变量不在此列，故 XWayland 应用（如 wechat）拿不到 GTK_IM_MODULE 而无法输入中文。
      # 这里的变量名在 autostart 时刻从本进程环境取值（即下面的 environment 文件内容），
      # 导入 systemd 与 D-Bus 激活环境后，launcher/门户激活拉起的程序才能继承。
      systemd.variables = [
        "DISPLAY"
        "WAYLAND_DISPLAY"
        "XDG_CURRENT_DESKTOP"
        "GTK_IM_MODULE"
        "QT_IM_MODULE"
        "QT_IM_MODULES"
        "SDL_IM_MODULE"
        "XMODIFIERS"
      ];
      environment = [
        "XDG_CURRENT_DESKTOP=labwc:wlroots"
        "XDG_SESSION_TYPE=wayland"
        "MOZ_ENABLE_WAYLAND=1"
        # 输入法变量需写入 labwc 的 environment 文件才能被合成器继承
        # XWayland 应用需要传统 X11 IM 变量
        "GTK_IM_MODULE=fcitx"
        "QT_IM_MODULE=fcitx"
        "XMODIFIERS=@im=fcitx"
        # Qt 6.8.2+ 使用 QT_IM_MODULES 回退机制；Qt < 6.8.2 需要 QT_IM_MODULE=fcitx
        "QT_IM_MODULES=wayland;fcitx;ibus"
        # SDL2 应用需要显式指定
        "SDL_IM_MODULE=fcitx"
        # Wayland 光标尺寸由输出缩放自动放大，保持基准避免二次缩放
        "XCURSOR_SIZE=24"
        "XCURSOR_THEME=Adwaita"
      ];
      # 只放需要继承合成器环境的一次性命令：autostart 是顺序执行的 shell 脚本，
      # 任何常驻进程都会阻塞脚本，导致 HM 追加在后面的 systemd 集成段无法执行；
      # 守护进程一律由 systemd 用户服务托管，不得放入 autostart。
      autostart = [
        "fcitx5 -d --replace"
        # XWayland 不跟随输出缩放，需单独设置；延时等待 XWayland 就绪
        "sh -c 'sleep 1; xsetroot -xcf ${pkgs.adwaita-icon-theme}/share/icons/Adwaita/cursors/left_ptr 42 2>/dev/null || true' &"
      ];
      rc = {
        # 间隙与缩略图切换器为 Noctalia 官方推荐的视觉协同
        core.gap = 10;
        theme = {
          cornerRadius = 8;
          dropShadows = "yes";
        };
        windowSwitcher = {
          "@preview" = "no";
          "@outlines" = "yes";
          osd."@style" = "thumbnail";
        };
        keyboard = {
          # 保留上游全部默认键位，自定义仅补充无冲突项
          default = true;
          keybind = [
            {
              "@key" = "W-t";
              action = {
                "@name" = "Execute";
                "@command" = "xdg-terminal-exec";
              };
            }
            {
              "@key" = "W-e";
              action = {
                "@name" = "Execute";
                "@command" = "xdg-open .";
              };
            }
            {
              "@key" = "W-space";
              action = {
                "@name" = "Execute";
                "@command" = "noctalia msg panel-toggle launcher";
              };
            }
            {
              "@key" = "W-s";
              action = {
                "@name" = "Execute";
                "@command" = "noctalia msg panel-toggle control-center";
              };
            }
            {
              "@key" = "W-comma";
              action = {
                "@name" = "Execute";
                "@command" = "noctalia msg settings-toggle";
              };
            }
            {
              "@key" = "W-v";
              action = {
                "@name" = "Execute";
                "@command" = "noctalia msg panel-toggle clipboard";
              };
            }
            {
              "@key" = "W-l";
              action = {
                "@name" = "Execute";
                "@command" = "noctalia msg session lock";
              };
            }
            {
              "@key" = "W-q";
              action = {
                "@name" = "Close";
              };
            }
            {
              "@key" = "W-f";
              action = {
                "@name" = "ToggleMaximize";
              };
            }
            {
              "@key" = "XF86AudioRaiseVolume";
              action = {
                "@name" = "Execute";
                "@command" = "noctalia msg volume-up";
              };
            }
            {
              "@key" = "XF86AudioLowerVolume";
              action = {
                "@name" = "Execute";
                "@command" = "noctalia msg volume-down";
              };
            }
            {
              "@key" = "XF86AudioMute";
              action = {
                "@name" = "Execute";
                "@command" = "noctalia msg volume-mute";
              };
            }
            {
              "@key" = "XF86MonBrightnessUp";
              action = {
                "@name" = "Execute";
                "@command" = "noctalia msg brightness-up";
              };
            }
            {
              "@key" = "XF86MonBrightnessDown";
              action = {
                "@name" = "Execute";
                "@command" = "noctalia msg brightness-down";
              };
            }
          ];
        };
      };
    };

  };

  environment.systemPackages = with pkgs; [
    wl-clipboard
    adwaita-icon-theme
    xsetroot
  ];
}
