{
  services.xserver.enable = true; # optional
  services.displayManager.sddm = {
    enable = true;
    theme = "breeze";
    wayland.enable = true;
    # enableHidpi = true;
    settings = {
      General.DisplayServer = "wayland";
    };
  };
  services.desktopManager.plasma6.enable = true;

  networking.firewall = rec {
    allowedTCPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
    allowedUDPPortRanges = allowedTCPPortRanges;
  };
}
