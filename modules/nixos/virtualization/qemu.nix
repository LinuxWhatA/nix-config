# QEMU/KVM（libvirt）—— 主机配置一行导入：(self + /modules/nixos/virtualization/qemu.nix)
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

  users.users.${flake.config.me.username} = {
    packages = [
      (pkgs.writeShellScriptBin "qemu-win11" ''
        exec qemu-kvm -cpu host -smp 12 -m 16384 -usb -device usb-tablet \
          -bios ${pkgs.OVMF.fd}/FV/OVMF.fd $@
      '')
    ];
    extraGroups = [
      "kvm"
      "libvirtd"
    ];
  };
}
