# WinApps —— 通过 RDP 启动 Windows 应用（包见 modules/nixos/virtualization/qemu.nix）。
{ flake, pkgs, ... }:

{
  home.packages = [
    flake.inputs.winapps.packages."${pkgs.stdenv.hostPlatform.system}".winapps
    flake.inputs.winapps.packages."${pkgs.stdenv.hostPlatform.system}".winapps-launcher
  ];
  home.file.".config/winapps/winapps.conf".text = ''
    RDP_USER="Administrator"
    RDP_ASKPASS="bash -c 'kwallet-query --folder winapps --read-password rdp kdewallet'"
    RDP_IP=""
    RDP_PORT="3389"
    VM_NAME="RDPWindows"
    WAFLAVOR="libvirt"
    RDP_SCALE="180"
    REMOVABLE_MEDIA="/run/media"
    RDP_FLAGS="/cert:tofu /sound /microphone /clipboard +home-drive /a:drive,Data,/mnt/Data"
  '';
}
