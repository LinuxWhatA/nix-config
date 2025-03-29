{
  lib,
  pkgs,
  ...
}:

{
  boot = {
    plymouth = {
      enable = true;
      theme = "550w";
      themePackages = [ pkgs.plymouth-550w-theme ];
    };
    loader.timeout = lib.mkDefault 5;
    kernelParams = [
      "quiet"
      "splash"
      "plymouth.nolog"
    ];
    consoleLogLevel = 0;
    initrd.verbose = false;
  };
}
