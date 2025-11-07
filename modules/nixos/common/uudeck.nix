{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.uudeck ];

  networking.firewall = rec {
    allowedTCPPorts = [ 16363 ];
    allowedUDPPorts = allowedTCPPorts;
  };
}
