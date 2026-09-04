{
  programs.kitty = {
    enable = true;
    shellIntegration.mode = "enabled";
    shellIntegration.enableZshIntegration = true;
    font = {
      name = "FiraCode Nerd Font Mono";
      size = 11;
    };
    themeFile = "Catppuccin-Mocha";
    settings = {
      enable_audio_bell = false; # 关闭音频提示音
      copy_on_select = "yes"; # 选中即复制
      mouse_map = "right press grabbed,ungrabbed paste_from_clipboard"; # 右键粘贴

      # 窗口设置
      confirm_os_window_close = -1; # 关闭窗口智能确认（有任务时提示，空闲时直接关闭）
      background_opacity = "0.85"; # 背景透明度
      dynamic_background_opacity = true; # 允许动态改变透明度
      hide_window_decorations = "no";
      window_padding_width = 4;

      # 光标与滚动
      cursor_shape = "beam";
      cursor_blink_interval = 0;
      scrollback_lines = 10000;

      # 标签栏
      tab_title_template = "[{index}] {title}";
      tab_bar_edge = "bottom";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";
      tab_bar_min_tabs = 1; # 避免标签栏消失
    };
  };
  # 将 kitty.desktop 设置为默认终端
  xdg.terminal-exec = {
    enable = true;
    settings.default = [ "kitty.desktop" ];
  };
  # 配置 Xfce 默认终端,解决 Thunar 调用终端的问题
  xdg.configFile."xfce4/helpers.rc".text = ''
    TerminalEmulator=kitty
  '';
}
