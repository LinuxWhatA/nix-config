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

  networking.networkmanager = {
    enable = true;
  };
}
