{ pkgs, ... }:
{
  hardware.bluetooth = {
    enable = true;
  };
  # MT7921 USB 蓝牙自动挂起导致配对设备连接缓慢/失败
  boot.extraModprobeConfig = "options btusb enable_autosuspend=N";
  # https://wiki.nixos.org/wiki/Bluetooth#USB_device_needs_to_be_unplugged/re-plugged_after_suspends
  systemd.services.reset-bluetooth-after-suspend = {
    description = "Reset Bluetooth USB device after system resume";
    after = [
      "sleep.target"
      "bluetooth.target"
      "systemd-suspend.service"
    ];
    wantedBy = [
      "sleep.target"
      "suspend.target"
    ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "reset-bluetooth.sh" ''
        for dev in $(${pkgs.usbutils}/bin/lsusb | grep -i bluetooth | ${pkgs.gawk}/bin/awk '{print $6}'); do
          ${pkgs.usbutils}/bin/usbreset "$dev"
        done
      ''}";
    };
  };
}
