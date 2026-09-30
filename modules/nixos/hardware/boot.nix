# 实体机公共启动配置（naix/redmi 共用）
{ pkgs, lib, ... }:

{
  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    binfmt.emulatedSystems = [
      "aarch64-linux"
      "i686-linux"
    ];
    supportedFilesystems = [ "ntfs" ];
    kernel.sysctl = {
      "fs.inotify.max_user_watches" = 524288;
    };

    plymouth = {
      enable = true;
      theme = "550w";
      themePackages = [ pkgs.plymouth-550w-theme ];
    };
    loader.timeout = lib.mkDefault 3;
    # 社区 silent boot 配方：udev 只记错误级；并关掉控制台光标
    kernelParams = [
      "quiet"
      "plymouth.nolog"
      "udev.log_level=3"
      "vt.global_cursor_default=0"
    ];
    consoleLogLevel = 0;
    initrd.verbose = false;
  };

  # 缩短 systemd 默认超时（默认 90s），避免慢盘服务被误杀，社区常用 30s
  systemd.settings.Manager = {
    DefaultTimeoutStartSec = "30s";
    DefaultTimeoutStopSec = "30s";
  };
}
