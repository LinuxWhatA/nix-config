{ flake, pkgs, ... }:

{
  virtualisation.libvirtd.enable = true;
  # virtualisation.libvirtd.swtpm.enable = true;
  programs.virt-manager.enable = true;
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  environment.systemPackages = with pkgs; [
    virtiofsd
    bridge-utils
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

  users.users.${flake.config.me.username}.extraGroups = [
    "kvm"
    "libvirt"
    "libvirtd"
  ];
}
