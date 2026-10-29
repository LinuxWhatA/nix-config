{
  flake,
  pkgs,
  lib,
  ...
}:
{
  wsl = {
    enable = true;
    defaultUser = flake.config.me.username;
    interop.register = true; # 解决 binfmt 冲突
    useWindowsDriver = true; # WSLg OpenGL 用 Windows 宿主驱动
    wslConf.interop = {
      enabled = true; # 启用互操作功能
      appendWindowsPath = false; # 不附加Windows PATH以提升速度
    };
    startMenuLaunchers = true;
  };
  systemd.services.systemd-binfmt.enable = false;
  services.envfs.enable = lib.mkForce false;

  # 避免 tarball 构建时 /etc/nixos 指向只读的 nix store 导致写 configuration.nix 失败
  environment.etc."nixos".enable = false;

  environment.systemPackages = [
    pkgs.xdg-utils # xdg-open/xdg-mime，Windows 侧默认程序打开文件依赖
    pkgs.glib # xdg-open 无桌面环境时的 gio 兜底
    pkgs.tray-tui # TUI 系统托盘
  ];

  networking.hostName = "wsl";

  security.sudo-rs.wheelNeedsPassword = false;
}
