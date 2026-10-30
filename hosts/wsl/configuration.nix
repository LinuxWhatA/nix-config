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
    tarball.configPath = flake.inputs.self; # /etc/nixos 由 tarball 写入仓库快照（可写，可在 guest 内 rebuild）
  };
  systemd.services.systemd-binfmt.enable = false;
  services.envfs.enable = lib.mkForce false;

  # /etc/nixos 已由 tarball.configPath 提供，不再挂 base/host.nix 的只读 store 链接
  environment.etc."nixos".enable = false;

  environment.systemPackages = with pkgs; [
    xdg-utils # xdg-open/xdg-mime，Windows 侧默认程序打开文件依赖
    glib # xdg-open 无桌面环境时的 gio 兜底
    tray-tui # TUI 系统托盘
  ];

  # 交换与内存额度由 Windows 的 .wslconfig 管，guest 再开 zram 只是和宿主争内存
  zramSwap.enable = false;

  networking.hostName = "wsl";

  security.sudo-rs.wheelNeedsPassword = false;
}
