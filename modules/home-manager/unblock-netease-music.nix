{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.my.services.unblock-netease-music;
in
{
  options.my.services.unblock-netease-music = {
    enable = lib.mkEnableOption "Enable unblock-netease-music";
    args = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Arguments to pass to unblock-netease-music";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.unblock-netease-music ];

    systemd.user.services.unblock-netease-music = {
      Unit = {
        Description = "Unblock Netease Music Service";
        After = "network.target";
      };
      Service = {
        ExecStart = "${pkgs.unblock-netease-music}/bin/unblock-netease-music ${cfg.args}";
        Restart = "always";
        RestartSec = "10";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
