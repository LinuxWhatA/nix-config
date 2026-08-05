{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  boot.kernel.sysctl."kernel.sysrq" = 1;
  hardware.enableRedistributableFirmware = true;
}
