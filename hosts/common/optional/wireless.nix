{
  pkgs,
  ...
}:

{
  hardware.bluetooth = {
    enable = true;
  };

  # https://wiki.nixos.org/wiki/Bluetooth#USB_device_needs_to_be_unplugged/re-plugged_after_suspends
  powerManagement.resumeCommands = ''
    ${pkgs.util-linux}/bin/rfkill block bluetooth
    ${pkgs.util-linux}/bin/rfkill unblock bluetooth
  '';

  networking.wireless = {
    enable = true;
  };

  # Ensure group exists
  users.groups.network = { };

  systemd.services.wpa_supplicant.preStart = "touch /etc/wpa_supplicant.conf";
}
