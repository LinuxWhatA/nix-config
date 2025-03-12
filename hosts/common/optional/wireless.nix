{
  pkgs,
  ...
}:

{
  hardware.bluetooth = {
    enable = true;
  };

  # https://wiki.nixos.org/wiki/Bluetooth#USB_device_needs_to_be_unplugged/re-plugged_after_suspends
  powerManagement.powerUpCommands = ''
    ${pkgs.usbutils}/bin/usbreset USB2.0-BT
  '';

  networking.wireless = {
    enable = true;
  };

  # Ensure group exists
  users.groups.network = { };

  systemd.services.wpa_supplicant.preStart = "touch /etc/wpa_supplicant.conf";
}
