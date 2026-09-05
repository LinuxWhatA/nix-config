{ pkgs, ... }:
{
  hardware.bluetooth = {
    enable = true;
  };
  # MT7921 USB 蓝牙自动挂起导致配对设备连接缓慢/失败
  boot.extraModprobeConfig = "options btusb enable_autosuspend=N";
}
