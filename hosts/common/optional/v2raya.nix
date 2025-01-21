{
  services.v2raya.enable = true;

  networking.firewall = {
    allowedTCPPorts = [
      20172
    ];
  };
}
