{
  services.v2raya.enable = true;

  networking.firewall = {
    allowedTCPPorts = [
      20172
    ];
  };

  environment.persistence = {
    "/persist" = {
      directories = [
        "/etc/v2raya"
      ];
    };
  };
}
