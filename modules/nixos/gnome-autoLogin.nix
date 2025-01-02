{
  lib,
  config,
  ...
}:

let
  cfg = config.services.gnome.autoLogin;
in
{
  options.services.gnome.autoLogin = {
    enable = lib.mkEnableOption "Enable automatic login for the user";

    username = lib.mkOption {
      type = lib.types.str;
    };
  };

  config = lib.mkIf cfg.enable {
    services.displayManager.autoLogin.enable = true;
    services.displayManager.autoLogin.user = "${cfg.username}";
    # Workaround for GNOME autologin
    # https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
    systemd.services."getty@tty1".enable = false;
    systemd.services."autovt@tty1".enable = false;
  };
}
