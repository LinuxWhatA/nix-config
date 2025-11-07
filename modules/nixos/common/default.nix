{ pkgs, ... }:
{
  imports =
    with builtins;
    map (fn: ./${fn}) (filter (fn: fn != "default.nix") (attrNames (readDir ./.)));

  nixpkgs.config.allowUnfree = true;

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "lwa";

  networking.networkmanager = {
    enable = true;
  };

  hardware.bluetooth = {
    enable = true;
  };
  # https://wiki.nixos.org/wiki/Bluetooth#USB_device_needs_to_be_unplugged/re-plugged_after_suspends
  powerManagement.powerUpCommands = ''
    ${pkgs.usbutils}/bin/usbreset USB2.0-BT
  '';

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  boot.kernel.sysctl."kernel.sysrq" = 1;
  hardware.enableRedistributableFirmware = true;
}
