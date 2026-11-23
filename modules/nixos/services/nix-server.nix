{ flake, ... }:
{
  # store 经 Nix 守护进程的 SSH 托管对外提供：复用 22 端口 + 公钥白名单鉴权，
  # 不用 nix-serve 那种无鉴权 HTTP 缓存（裸 5000 端口，任意对端可读取/获取 nar）。
  # keys 取 me.sshKey：仅本仓持有对应私钥者能拉取 store。
  # nix.sshServe 强制开启 openssh 但不开放防火墙：本服务依赖 22 端口已放行，
  # 由使用方主机保证，否则 store 静默不可达。
  nix.sshServe = {
    enable = true;
    protocol = "ssh-ng";
    keys = [ flake.config.me.sshKey ];
  };
}
