{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.my.kmscon;
in
{
  options.my.kmscon = {
    enable = lib.mkEnableOption "Enable kmscon";

    autologinUser = lib.mkOption {
      type = lib.types.str;
    };
  };

  config = lib.mkIf cfg.enable {
    services.kmscon = {
      enable = true;
      autologinUser = cfg.autologinUser;
      fonts = [
        {
          name = "MesloLGS NF";
          package = pkgs.meslo-lgs-nf;
        }
      ];
    };
  };
}
