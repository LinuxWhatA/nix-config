{ pkgs, config, ... }:

{
  # TODO: Not working
  systemd.services.uudeck = {
    after = [ "network.target" ];
    # wantedBy = [ "multi-user.target" ];
    description = "UU Accelerator for Steam Deck";
    # environment = config.environment.variables;
    serviceConfig = {
      ExecStart = "${pkgs.uudeck}/bin/uudeck";
      WorkingDirectory = "/tmp/uu";
      Restart = "always";
      RestartSec = "5";
    };
  };

  environment.systemPackages = [ pkgs.uudeck ];

  networking.firewall = rec {
    allowedTCPPorts = [ 16363 ];
    allowedUDPPorts = allowedTCPPorts;
  };
}
