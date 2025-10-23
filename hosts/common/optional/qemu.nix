{ pkgs, ... }:

{
  virtualisation.libvirtd = {
    enable = true;
  };
  programs.virt-manager.enable = true;

  environment.systemPackages = with pkgs; [
    virtiofsd
  ];

  networking.firewall = {
    allowedTCPPortRanges = [
      # spice
      {
        from = 5900;
        to = 5999;
      }
    ];
    allowedTCPPorts = [
      # libvirt
      16509
    ];
  };
}
