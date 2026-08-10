# 用户接入：任意主机一行导入本文件即可获得
#   - 用户创建（shell、组、密码）
#   - home-manager 系统内托管
#   - 注：用户模块注入必须在各主机各自的 home-manager.users.<name>.imports 中
#     写明（HM 的该选项不接受 mkDefault/mkForce 包装，无法集中设默认值）
{ flake, pkgs, ... }:
{
  users.users.${flake.config.me.username} = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    hashedPassword = "$6$6aT0cza7dVGIOdsf$ICgv1WOo255hp41vzsz2c7m1BtI51MFfmR7K7qJdJ4zRR2yFSNS0mKsqSMhMPPSWbShpi5UzgMmOkd/9UMxEg0";
  };

  home-manager.backupFileExtension = "hm-backup";
}
