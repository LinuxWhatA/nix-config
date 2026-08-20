{
  services.nfs.server = {
    enable = true;
    exports = ''
      # 仅限私网段可读写；NFSv4 客户端用单端口 2049
      /mnt/Data 192.168.0.0/16(rw,sync,no_subtree_check)
    '';
  };
  # NFSv4 只需 TCP 2049；若引入 NFSv3 客户端，还需放行 rpcbind(111) 与 mountd
  networking.firewall.allowedTCPPorts = [ 2049 ];
}
