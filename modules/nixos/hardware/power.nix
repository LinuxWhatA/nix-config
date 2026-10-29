# 电源档位（platform profile / EPP / boost）由 ppd 管，桌面经它的 DBus 接口切换；
# 放在主机层：它管设备电源策略，与合成器无关，换桌面不必每处重抄。
{
  services.power-profiles-daemon.enable = true;
}
