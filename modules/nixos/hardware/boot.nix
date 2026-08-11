# 实体机公共启动配置（naix/redmi 共用）
{ pkgs, lib, ... }:

{
  boot.kernelPackages = pkgs.linuxPackages_zen;
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "i686-linux"
  ];
  boot.supportedFilesystems = [ "ntfs" ];
  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 524288;
  };

  users.mutableUsers = lib.mkDefault true;
}
