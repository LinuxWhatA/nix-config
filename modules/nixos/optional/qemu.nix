{ flake, pkgs, ... }:

{
  virtualisation.libvirtd = {
    enable = true;
  };
  programs.virt-manager.enable = true;

  environment.systemPackages = with pkgs; [
    virtiofsd
  ];

  networking.firewall = {
    # spice
    allowedTCPPortRanges = [
      {
        from = 5900;
        to = 5999;
      }
    ];
    # libvirt
    allowedTCPPorts = [
      16509
    ];
  };

  users.users.${flake.config.me.username}.extraGroups = [ "libvirtd" ];
}
