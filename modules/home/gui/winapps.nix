# 通过 RDP 启动 Windows 应用
{ pkgs, ... }:

{
  home.packages = [
    pkgs.winapps
    pkgs.winapps-launcher
  ];
  home.file.".config/winapps/winapps.conf".text = ''
    RDP_USER="Administrator"
    RDP_ASKPASS="bash -c '${pkgs.zenity}/bin/zenity --password 2>/dev/null'"
    RDP_IP=""
    RDP_PORT="3389"
    VM_NAME="RDPWindows"
    WAFLAVOR="libvirt"
    RDP_SCALE="180"
    REMOVABLE_MEDIA="/run/media"
    RDP_FLAGS="/cert:tofu /sound /microphone /clipboard +home-drive /a:drive,Data,/mnt/Data"
  '';
}
