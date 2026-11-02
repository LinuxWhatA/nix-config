# wsl 主机
{
  flake,
  config,
  lib,
  ...
}:
let
  inherit (flake) inputs;
in
{
  imports = [
    ./configuration.nix
    inputs.nixos-wsl.nixosModules.wsl
    flake.config.nixosModules.base.default
    flake.config.nixosModules.gui.clash
    flake.config.nixosModules.gui.thunar
    flake.config.nixosModules.desktop.labwc
  ];

  home-manager.users.${flake.config.me.username} = {
    imports = [
      flake.config.homeModules.cli.default
      flake.config.homeModules.gui.kitty
      flake.config.homeModules.gui.noctalia
    ];

    wayland.windowManager.labwc = {
      # 共享 labwc.nix 只导入输入法变量；WSLg 下 noctalia/D-Bus 拉起的程序也须走
      # XWayland（否则拿不到输入法），故补进 configuration.nix 的 X11 强制变量；
      # 值在 autostart 时取自 labwc 进程环境（PAM 注入 sessionVariables）。
      systemd.variables = [
        "GDK_BACKEND"
        "QT_QPA_PLATFORM"
        "GLFW_IM_MODULE"
        "NIXOS_OZONE_WL"
      ];

      # WSLg 的 Wayland 客户端拿不到任何 IME（外部 fcitx5 的 waylandim 已禁，Windows
      # IME 也不桥接给 Wayland），故本桌面全走 X11 才有输入法。configuration.nix 的
      # PAM 变量已把值设为 0（覆盖 systemd/D-Bus 拉起的进程），但 labwc 启动时又会
      # 读取共享 environment 里的 =1，故这里再压回 0；按行 setenv、后值覆盖前值，
      # 追加一行即可，不必整表重写（共享列表以后加变量也不会漏）。
      environment = lib.mkAfter [ "MOZ_ENABLE_WAYLAND=0" ];

      # WSLg 独占 zwp_input_method_v1，fcitx5 的 wayland 前端绑定被拒而崩溃
      # （microsoft/wslg#1430），故覆盖 labwc.nix 的 fcitx5 启动命令，禁用 Wayland
      # 前端。--disable 取单参数逗号分隔：fcitx5 的 getopt 对每个 --disable 是赋值
      # 而非累积（后者胜出），拆成两个参数会静默丢弃前一个；且 waylandim 前端依赖
      # wayland 模块，须二者都禁——只禁 waylandim 时 wayland 模块仍会连 WSLg 的
      # wayland socket，连接一断便整体退出（waylandmodule 的 removeConnection →
      # instance_->exit()）。
      autostart = lib.mkForce [
        "${config.i18n.inputMethod.package}/bin/fcitx5 -d --replace --disable=wayland,waylandim"
      ];
    };

    # kitty 的 linux_display_server=auto 只看 WAYLAND_DISPLAY，不认 GDK/QT/GLFW 的
    # X11 强制变量；会话里该变量始终存在，故须显式改 X11，否则 Wayland 下没有输入法
    # 前端可用（原因见上面 fcitx5 的 --disable 说明）。
    programs.kitty.settings.linux_display_server = "x11";
  };

  # 生成 nixos.wsl
  # sudo nix run '.#nixosConfigurations.wsl.config.system.build.tarballBuilder'
}
