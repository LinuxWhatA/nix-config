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

  # 录屏/截图仅 wlr 实现，其他接口需 gtk/kde 回退
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
    configPackages = [ pkgs.labwc ];
    # labwc 会话的 XDG_CURRENT_DESKTOP 为 labwc，需为该桌面单独指定后端
    config.labwc = {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.Access" = [ "gtk" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      "org.freedesktop.impl.portal.Notification" = [ "gtk" ];
      "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
    };
  };

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
        theme.templates = {
          builtin_ids = [ "labwc" ];
        };
        bar.default = {
          margin_ends = 0;
          end = [
            "network_tx"
            "network_rx"
            "tray"
            "notifications"
            "clipboard"
            "network"
            "bluetooth"
            "volume"
            "brightness"
            "battery"
            "control-center"
            "session"
          ];
          start = [
            "launcher"
            "wallpaper"
            "workspaces"
            "media"
          ];
        };
        widget.network_rx = {
          glyph = "arrow-narrow-down";
          visualization = "none";
        };
        widget.network_tx = {
          glyph = "arrow-narrow-up";
          visualization = "none";
        };
        dock = {
          auto_hide = true;
          enabled = true;
          launcher_position = "start";
          reserve_space = false;
        };
        osd.kinds = {
          keyboard_layout = false;
        };
        shell.panel = {
          clipboard_position = "top_right";
        };
      };
    };

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

      # 空闲 5 分钟关屏：交由 systemd 随 graphical-session.target 启停，
      # 该服务不含 swayidle 之外的 PATH，wlopm 需写绝对路径
      swayidle = {
        enable = true;
        timeouts = [
          {
            timeout = 300;
            # 星号必须用引号保护：命令经 sh -c 执行，裸 * 会被展开成当前目录文件名
            command = "${pkgs.wlopm}/bin/wlopm --off '*'";
            resumeCommand = "${pkgs.wlopm}/bin/wlopm --on '*'";
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
      # 任何常驻进程都会阻塞脚本，导致 HM 追加在后面的 systemd 集成段无法执行。
      # 守护进程（polkit agent、swayidle 等）改由 systemd 用户服务托管。
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

    # polkit 认证代理：该包只提供 XDG autostart 文件，labwc 不会读取，
    # 需由 systemd 用户服务拉起；绑定 graphical-session.target 以保证启动时
    # WAYLAND_DISPLAY 已被 dbus-update-activation-environment 导入 systemd 环境
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
  };

  environment.systemPackages = with pkgs; [
    kdePackages.polkit-kde-agent-1
    swayidle
    wlopm
    wl-clipboard
    adwaita-icon-theme
    xsetroot
  ];
  # 不再安装 XDG applications.menu：noctalia 启动器与 labwc 根菜单都直接消费 .desktop 文件，
  # 仅为一份菜单把整套 plasma-workspace 拉进系统闭包并不划算
}
