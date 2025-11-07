{ flake, pkgs, ... }:

{
  services.kmscon = {
    enable = true;
    autologinUser = flake.config.me.username;
    fonts = [
      {
        name = "MesloLGS NF";
        package = pkgs.meslo-lgs-nf;
      }
    ];
  };
}
