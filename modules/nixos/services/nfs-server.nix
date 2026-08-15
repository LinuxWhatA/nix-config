{
  services.nfs.server = {
    enable = true;
    exports = ''
      # 仅限私网段可读写（原 *(rw) 对全网开放）；NFSv4 客户端用单端口 2049
      /mnt/TiPlus5000/OS 192.168.0.0/16(rw,sync,no_subtree_check) \
        10.0.0.0/8(rw,sync,no_subtree_check) 172.16.0.0/12(rw,sync,no_subtree_check)
    '';
  };
  # NFSv4 只需 TCP 2049；若引入 NFSv3 客户端，还需放行 rpcbind(111) 与 mountd
  networking.firewall.allowedTCPPorts = [ 2049 ];
}
