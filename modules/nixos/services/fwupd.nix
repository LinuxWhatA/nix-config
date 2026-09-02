{ lib, ... }:
{
  # nixos-hardware common-pc-laptop 默认 services.fwupd.enable = true
  # 保留守护以支持 fwupdmgr / Discover，但禁开机刷新定时器（原 8.5s 墙钟 + 1.25s 守护）
  services.fwupd.enable = lib.mkDefault true;
  systemd.timers.fwupd-refresh.wantedBy = lib.mkForce [ ];
}
