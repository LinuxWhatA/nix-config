{
  flake,
  pkgs,
  ...
}:
{
  # 供 autostart 的 root 光标与 GTK/X11 光标主题（pointerCursor 同源）
  environment.systemPackages = with pkgs; [
    adwaita-icon-theme
    xsetroot
  ];

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

    # 光标统一取逻辑基准 24：原生光标随输出 scale 放大为 42px 物理，
    # XWayland root 取同基准（见 autostart）
    home.pointerCursor = {
      enable = true;
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
      size = 24;
      gtk.enable = true;
      x11.enable = true;
    };

    wayland.windowManager.labwc = {
      environment = [
        # 与 pointerCursor 同基准的运行时值：labwc 按此逻辑尺寸加载光标主题
        "XCURSOR_SIZE=24"
        "XCURSOR_THEME=Adwaita"
      ];
      # autostart 只放一次性命令；常驻进程会阻塞顺序执行的脚本（契约与
      # desktop-host 的 fcitx5 一致）。XWayland root 光标不经整数 buffer_scale 折算，
      # 须用逻辑基准 24px 才与原生一致；XWayland 就绪前设置必失败，故延时。
      autostart = [
        "sh -c 'sleep 1; xsetroot -xcf ${pkgs.adwaita-icon-theme}/share/icons/Adwaita/cursors/left_ptr 24 2>/dev/null || true' &"
      ];
    };
  };
}
