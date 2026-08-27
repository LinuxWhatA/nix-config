# 实体机公共启动配置（naix/redmi 共用）
{ pkgs, ... }:

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
  };
}
