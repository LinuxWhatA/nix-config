# Wayfire 桌面 —— 主机配置一行导入：(self + /modules/nixos/desktop/wayfire.nix)
{
  flake,
  pkgs,
  ...
}:
{
  # 桌面需要用户态 GUI 模块
  home-manager.sharedModules = [ flake.inputs.self.homeModules.gui ];

  programs.wayfire = {
    enable = true;
    plugins = with pkgs.wayfirePlugins; [
      wcm
      wf-shell
      wayfire-plugins-extra
    ];
  };

  services.greetd = {
    enable = true;
    settings = rec {
      initial_session = {
        command = "${pkgs.uwsm}/bin/uwsm start wayfire";
        user = flake.config.me.username;
      };
      default_session = initial_session;
    };
  };

  programs.uwsm = {
    enable = true;
    waylandCompositors.wayfire = {
      prettyName = "Wayfire";
      binPath = "${pkgs.wayfire}/bin/wayfire";
    };
  };

  services.gnome.gnome-keyring.enable = true;

  home-manager.users.${flake.config.me.username} = {
    wayland.windowManager.wayfire = {
      enable = true;
      package = null;
      systemd.enable = true;
      settings = {
        core = {
          systemd = true;
          preferred_decoration_mode = "server";
          plugins = ''
            alpha \
            animate \
            command \
            cube \
            decoration \
            expo \
            fast-switcher \
            fisheye \
            foreign-toplevel \
            grid \
            gtk-shell \
            idle \
            invert \
            move \
            obs \
            oswitch \
            place \
            resize \
            session-lock \
            shortcuts-inhibit \
            switcher \
            vswitch \
            wayfire-shell \
            window-rules \
            wm-actions \
            wobbly \
            wrot \
            zoom \
            showdesktop \
            input-method-v1'';
        };
        "output:eDP-1".scale = 1.75;
        autostart = {
          notifications = "mako";
        };
        wayfire-shell.toggle_menu = "<super>";
        command = {
          # ===== 亮度控制 =====
          repeatable_binding_brightness_up = "KEY_BRIGHTNESSUP";
          command_brightness_up = "brightnessctl s +5%";
          repeatable_binding_brightness_down = "KEY_BRIGHTNESSDOWN";
          command_brightness_down = "brightnessctl s 5%-";
          # ===== 音量控制（PipeWire） =====
          repeatable_binding_volume_up = "KEY_VOLUMEUP";
          command_volume_up = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
          repeatable_binding_volume_down = "KEY_VOLUMEDOWN";
          command_volume_down = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
          binding_volume_mute = "KEY_MUTE";
          command_volume_mute = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          # ===== 快捷键 =====
          binding_terminal_alt = "<ctrl> <alt> KEY_T";
          command_terminal_alt = "konsole";
          binding_launcher = "<super> KEY_SPACE";
          command_launcher = "wofi --show drun";
          binding_clipboard = "<super> KEY_V";
          command_clipboard = "";
        };
      };
    };
    home.packages = with pkgs; [
      brightnessctl
      wofi # 应用启动器
      grim # 截图
      slurp # 选区
      wl-clipboard # 剪贴板
      libnotify # 通知
      swaybg # 壁纸
    ];
    services.mako.enable = true;
  };

  environment.sessionVariables = {
    XDG_CURRENT_DESKTOP = "Wayfire";
    XDG_SESSION_TYPE = "wayland";
    QT_QPA_PLATFORM = "wayland";
    GDK_BACKEND = "wayland";
  };

  environment.systemPackages = with pkgs; [
    wayland-utils
    kdePackages.konsole
    kdePackages.dolphin
    kdePackages.qtsvg
    kdePackages.kio
    kdePackages.kio-fuse
    kdePackages.kio-extras
  ];
  environment.etc."xdg/menus/applications.menu".source =
    "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
}
