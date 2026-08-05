{
  services.nix-serve = {
    enable = true;
    bindAddress = "0.0.0.0";
    port = 5000;
  };

  networking.firewall.allowedTCPPorts = [ 5000 ];
}
