{
  hardware.bluetooth = {
    enable = true;

    # BlueZ 重连按 profile 白名单走，默认仅音频类；加入 HID 使任意已配对 HID 设备断链后自动回连
    settings.Policy = {
      AutoEnable = true;
      ReconnectUUIDs = "00001812-0000-1000-8000-00805f9b34fb,00001124-0000-1000-8000-00805f9b34fb";
      ReconnectAttempts = 10;
      ReconnectIntervals = "1,2,4,8,16,32,64,64,64,64";
    };

    # 避免主机侧因空闲超时主动断开 HID（BlueZ main.conf [General] 段的 IdleTimeout）
    settings.General.IdleTimeout = 0;
  };

  # MT7921 USB 蓝牙自动挂起导致配对设备连接缓慢/失败
  boot.extraModprobeConfig = "options btusb enable_autosuspend=N";
}
