# 与具体硬件无关的 opt-in persistence 部分。
#
# 引入 impermanence，并声明系统级需要持久化的路径；持久化存储的挂载
# （/ 为 tmpfs、/persist 为 btrfs subvol 等）属硬件配置，由各主机的 hardware-configuration 决定。
{
  flake,
  ...
}:

{
  imports = [ flake.inputs.impermanence.nixosModules.impermanence ];

  environment.persistence."/persist" = {
    files = [
      "/etc/machine-id"
    ];
    directories = [
      "/etc/NetworkManager/system-connections"
      "/var/lib"
      "/var/log"
      "/srv"
      # 当 / 为 tmpfs 时，/tmp 占用内存，Nix 构建易 OOM
      "/tmp"
    ];
  };

  # 配合持久化的 "/tmp"：每次启动清空，否则落盘的 /tmp 残留会跨重启累积。
  boot.tmp.cleanOnBoot = true;
}
