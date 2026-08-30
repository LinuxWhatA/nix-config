{
  flake,
  pkgs,
  lib,
  config,
  ...
}:

{
  imports = [
    (flake.inputs.denial-nixos.nixosModules.default { inherit pkgs lib config; })
  ];

  services = {
    denial = {
      enable = true;
      user = "${flake.config.me.username}";
    };

    displayManager = {
      gdm.enable = true;
      defaultSession = "denial";
      sessionPackages = [ config.services.denial.selectedPackage ];
    };
  };

  environment.systemPackages = [
    pkgs.kitty
    pkgs.kdePackages.dolphin
  ];
}
