{
  pkgs,
  config,
  ...
}:

{
  console = {
    useXkbConfig = true;
    earlySetup = false;
  };

  boot = {
    plymouth = {
      enable = true;
      theme = "550w";
      themePackages = [ pkgs.plymouth-550w-theme ];
    };
    loader.timeout = 0;
    kernelParams = [
      "quiet"
      "loglevel=3"
      "systemd.show_status=auto"
      "udev.log_level=3"
      "rd.udev.log_level=3"
      "vt.global_cursor_default=0"
    ];
    consoleLogLevel = 0;
    initrd.verbose = false;
  };
}
