{ lib, config, ... }:

{
  # 提高 sudoer 的文件描述符上限
  security.pam.loginLimits = [
    {
      domain = "@wheel";
      item = "nofile";
      type = "soft";
      value = "524288";
    }
    {
      domain = "@wheel";
      item = "nofile";
      type = "hard";
      value = "1048576";
    }
  ];

  security.sudo-rs = {
    enable = lib.mkIf (!config.system.build ? isoImage) true;
    extraConfig = "Defaults env_reset,timestamp_timeout=60";
  };
}
