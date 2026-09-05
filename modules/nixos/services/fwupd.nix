{ lib, ... }:
{
  # nixos-hardware common-pc-laptop 默认开启 fwupd：保留守护供 fwupdmgr/Discover 使用，
  # 禁开机刷新定时器（避免启动期刷新拖慢）
  services.fwupd.enable = lib.mkDefault true;
  systemd.timers.fwupd-refresh.wantedBy = lib.mkForce [ ];
}
