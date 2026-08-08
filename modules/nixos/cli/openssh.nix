{
  lib,
  pkgs,
  flake,
  config,
  ...
}:

let
  # Sops 需要在 persist 目录挂载前就拿到密钥，
  # 因此仅持久化密钥不够，必须直接指向 /persist。
  # 未导入 impermanence 时 persistence 选项不存在，需先探测
  hasOptinPersistence =
    (config.environment ? persistence)
    && (config.environment.persistence ? "/persist");
in
{
  users.users.root.openssh.authorizedKeys.keys = [ flake.config.me.sshKey ];
  users.users."${flake.config.me.username}" = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];

    openssh.authorizedKeys.keys = [ flake.config.me.sshKey ];
    hashedPassword = "$6$6aT0cza7dVGIOdsf$ICgv1WOo255hp41vzsz2c7m1BtI51MFfmR7K7qJdJ4zRR2yFSNS0mKsqSMhMPPSWbShpi5UzgMmOkd/9UMxEg0";
  };

  services.openssh = {
    enable = true;
    settings = {
      # Harden
      PasswordAuthentication = false;
      PermitRootLogin = "no";

      # 自动移除过期 socket
      StreamLocalBindUnlink = "yes";
      # 允许端口转发到任意目标
      GatewayPorts = "clientspecified";
      # 允许转发 WAYLAND_DISPLAY 环境变量
      AcceptEnv = [ "WAYLAND_DISPLAY" ];
      X11Forwarding = true;
    };

    hostKeys = [
      {
        path = "${lib.optionalString hasOptinPersistence "/persist"}/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };
}
