{ pkgs, ... }:

{
  # Increase open file limit for sudoers
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
    enable = true;
    extraConfig = "Defaults env_reset,timestamp_timeout=60";
  };

  security.pki.certificateFiles = [
    "${pkgs.dev-sidecar}/dev-sidecar.ca.crt"
  ];
}
