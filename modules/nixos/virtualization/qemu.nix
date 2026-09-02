{
  flake,
  pkgs,
  lib,
  ...
}:

{
  virtualisation.libvirtd = {
    enable = true;
    # qemu.swtpm.enable = true;
    qemu.vhostUserPackages = with pkgs; [ virtiofsd ];
    # 按需启动虚拟机，不在开机时自动启动，避免阻塞
    onBoot = "ignore";
    onShutdown = "suspend";
  };

  # libvirtd 默认 WantedBy multi-user.target 阻塞 critical-chain 1.6s，改为 socket 激活
  systemd.services.libvirtd.wantedBy = lib.mkForce [ ];
  # libvirt-guests 仅在 libvirtd 启完后恢复 VM 状态，但 onBoot="ignore" 下开机无 VM 可恢复
  # 其 After=libvirtd.service 把整条关键链拉长 ~1.6s，禁掉
  systemd.services.libvirt-guests.wantedBy = lib.mkForce [ ];
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
