# 与具体硬件无关的 opt-in persistence 部分。
#
# 引入 impermanence，并声明系统级需要持久化的路径。
# 持久化存储本身的挂载（/ 为 tmpfs、/persist 为 btrfs subvol、btrfs 快照根或完全不临时）
# 属于硬件相关配置，由各主机的 hardware-configuration 决定，本文件不感知。
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
      "/var/lib/bluetooth"
      "/var/lib/libvirt"
      "/var/lib/fprint"
      "/var/lib/systemd"
      "/var/lib/nixos"
      "/var/lib/todesk"
      "/var/log"
      "/srv"
      # 当 / 为 tmpfs 时，/tmp 占用内存，Nix 构建易 OOM。
      # 持久化后 /tmp 变为 /persist/tmp 的 bind mount（数据落盘），
      # 再靠下方 boot.tmp.cleanOnBoot 在每次启动时清空，避免脏数据跨重启累积。
      "/tmp"
    ];
  };

  # 配合持久化的 "/tmp"：每次启动清空，否则落盘的 /tmp 残留会跨重启累积。
  # 注：此选项默认值为 false（见 nixpkgs module system/boot/tmp.nix），必须显式开启。
  boot.tmp.cleanOnBoot = true;
}
