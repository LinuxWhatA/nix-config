{ flake, pkgs, ... }:

let
  pkg = pkgs.sunloginclient;
in
{
  # 上游二进制硬编码 /usr/local/awesun（stub 方案不修改二进制），
  # 用符号链接将其指向 store 内的应用树；/var/log/awesun 为日志目录
  systemd.tmpfiles.rules = [
    "L+ /usr/local/awesun - - - ${pkg}/opt/awesun"
    "d /var/log/awesun 0777 root root -"
  ];

  systemd.services.sunloginclient = {
    description = "Sunlogin (向日葵) remote-control daemon";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkg}/opt/awesun/bin/awesun_daemon -m server -name awesun";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  home-manager.users.${flake.config.me.username}.home.packages = [ pkg ];
}
