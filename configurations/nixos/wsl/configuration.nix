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

  users.mutableUsers = true;

  environment.systemPackages = [
    pkgs.sni-host
    pkgs.tray-host
    pkgs.kdePackages.dolphin
    pkgs.xdg-utils # xdg-open/xdg-mime,托盘菜单"打开目录"依赖
    pkgs.glib # xdg-open 无桌面环境时的 gio 兜底
  ];
  # WSLg 无桌面环境,xdg-open/gio 依此注册打开目录的默认文件管理器
  xdg.mime.defaultApplications = {
    "inode/directory" = "org.kde.dolphin.desktop";
  };

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "wsl";
  system.stateVersion = "26.11";

  security.sudo-rs.wheelNeedsPassword = false;

  home-manager.users.${flake.config.me.username}.home.stateVersion = "26.11";
}
