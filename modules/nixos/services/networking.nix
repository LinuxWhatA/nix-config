{
  networking.networkmanager = {
    enable = true;
  };

  # 桌面不需要等网络就绪，wait-online 会阻塞 network-online.target 数秒，社区推荐禁用
  systemd.services.NetworkManager-wait-online.enable = false;
}
