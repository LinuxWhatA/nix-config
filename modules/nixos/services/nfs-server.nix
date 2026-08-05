{
  services.nfs.server = {
    enable = true;
    exports = ''
      /mnt/TiPlus5000/OS *(rw)
    '';
  };
  # 在防火墙上开放NFS端口
  networking.firewall.allowedTCPPorts = [ 2049 ];
}
