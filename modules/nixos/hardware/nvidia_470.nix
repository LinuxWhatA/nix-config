{ config, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];
  nixpkgs.config.nvidia.acceptLicense = true;

  hardware.nvidia = {
    open = false;
    package = config.boot.kernelPackages.nvidia_x11_legacy470;
    nvidiaSettings = true;
    modesetting.enable = true;
    powerManagement.enable = true;

    prime = {
      sync.enable = true;
      offload = {
        enable = false;
        enableOffloadCmd = false;
      };
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:4:0:0";
    };
  };
}
