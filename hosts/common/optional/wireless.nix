{
  config,
  ...
}:

{
  hardware.bluetooth = {
    enable = true;
  };

  networking.wireless = {
    enable = true;
  };

  # Ensure group exists
  users.groups.network = { };

  systemd.services.wpa_supplicant.preStart = "touch /etc/wpa_supplicant.conf";
}
