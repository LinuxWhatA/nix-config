{ pkgs, flake, ... }:
{
  imports =
    with builtins;
    map (fn: ./${fn}) (filter (fn: fn != "default.nix") (attrNames (readDir ./.)));

  nixpkgs.config.allowUnfree = true;

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = flake.config.me.username;

  networking.networkmanager = {
    enable = true;
  };

  hardware.bluetooth = {
    enable = true;
  };
  # https://wiki.nixos.org/wiki/Bluetooth#USB_device_needs_to_be_unplugged/re-plugged_after_suspends
  systemd.services.reset-bluetooth-after-suspend = {
    description = "Reset Bluetooth USB device after system resume";
    after = [ "sleep.target" ];
    wantedBy = [ "sleep.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeScript "reset-bluetooth.sh" ''
        #!/${pkgs.bash}/bin/bash
        # 自动查找所有蓝牙设备并重置
        for dev in $(${pkgs.usbutils}/bin/lsusb | grep -i bluetooth | awk '{print $6}'); do
          ${pkgs.usbutils}/bin/usbreset "$dev"
        done
      ''}";
    };
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  boot.kernel.sysctl."kernel.sysrq" = 1;
  hardware.enableRedistributableFirmware = true;
}
