{
  config,
  flake,
  pkgs,
  ...
}:
let
  # 输入法环境注入：noctalia 拉起的 XWayland 应用（如 wechat）继承的是 systemd/D-Bus
  # 用户环境；niri-session 启动时会把自身进程环境整体导入该环境（HM niri 模块注明
  # systemd.variables 对 niri 无用），因此只需在拉起 niri-session 前 export 这些变量，
  # launcher/门户激活拉起的程序即可拿到 GTK_IM_MODULE 等而正常输入中文。
  sessionEnv = pkgs.writeShellScript "niri-session-env" ''
    export GTK_IM_MODULE=fcitx
    export QT_IM_MODULE=fcitx
    export QT_IM_MODULES='wayland;fcitx;ibus'
    export SDL_IM_MODULE=fcitx
    export XMODIFIERS=@im=fcitx
    exec ${config.programs.niri.package}/bin/niri-session
  '';
in
{
  programs.niri.enable = true;

  security.polkit.enable = true; # polkit 认证弹窗由 noctalia 原生 agent 提供（见 noctalia.nix）

  services = {
    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${sessionEnv}";
          user = flake.config.me.username;
        };
      };
    };
    upower.enable = true;
    gnome.gnome-keyring.enable = true;
    power-profiles-daemon.enable = true;
  };

  # 门户后端：niri 非 wlroots，xdg-desktop-portal-wlr 不可用，录屏/截图须由
  # xdg-desktop-portal-gnome 承担（官方推荐）。niri 包自带 portals.conf
  # （gnome 优先、gtk 兜底），经 configPackages 引入即可，无需手写 config.niri；
  # Secret 由 gnome-keyring 提供（services.gnome.gnome-keyring 已启用）
  xdg.portal = {
    enable = true;
    configPackages = [ config.programs.niri.package ];
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
  };

  home-manager.users.${flake.config.me.username} = {
    imports = [
      flake.inputs.noctalia.homeModules.default
      ./noctalia.nix
    ];

    wayland.windowManager.niri = {
      enable = true;
      # portal 在系统层 xdg.portal 统一管理（含 niri 自带 portals.conf），
      # 关闭 HM 模块默认注入的 gnome portal，避免与系统层重复
      portalPackage = null;
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
          # Mod+V 已被剪贴板占用，浮动切换放在不冲突的 Mod+Ctrl+V
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

      # 启动项原则：常驻进程一律由 systemd 用户服务托管，此处只放一次性/自带驻留命令。
      # niri 不消费 XDG autostart，fcitx5 在此显式拉起：-d 自行 daemonize、
      # --replace 接管已有实例，避免出现重复实例
      extraConfig = ''
        spawn-at-startup "${pkgs.fcitx5}/bin/fcitx5" "-d" "--replace"
      '';
    };

    home.packages = with pkgs; [
      xwayland-satellite # XWayland 支持（由独立的 xwayland-satellite 提供）
    ];
  };

  # 桌面公共工具：wl-clipboard 供 Wayland 剪贴板使用，adwaita-icon-theme 提供图标与光标主题
  environment.systemPackages = with pkgs; [
    wl-clipboard
    adwaita-icon-theme
  ];
}
