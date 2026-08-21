# QEMU/KVM（libvirt）—— 主机配置一行导入：(self + /modules/nixos/virtualization/qemu.nix)
{ flake, pkgs, ... }:

{
  virtualisation.libvirtd = {
    enable = true;
    # qemu.swtpm.enable = true;
    qemu.vhostUserPackages = with pkgs; [ virtiofsd ];
  };
  programs.virt-manager.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  environment.systemPackages = with pkgs; [
    virtiofsd
    bridge-utils
  ];

  networking.firewall.trustedInterfaces = [ "virbr0" ];

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
