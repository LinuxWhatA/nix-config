{
  # HUD 不随会话全局注入（MANGOHUD=1）：只对显式以 `mangohud` 前缀启动的进程生效，
  # 由游戏启动侧按需启用；启用即默认显示，下方热键用于运行时临时切换/挪位/录屏/重载
  programs.mangohud = {
    enable = true;
    settings = {
      frame_timing = false;
      cpu_stats = true;
      cpu_temp = true;
      gpu_stats = true;
      gpu_temp = true;
      ram = true;
      vram = true;
      hud_compact = true;

      toggle_hud = "Shift_L+F1";
      toggle_hud_position = "Shift_L+F2";
      toggle_logging = "Shift_L+F3";
      reload_cfg = "Shift_L+F4";
    };
  };
}
