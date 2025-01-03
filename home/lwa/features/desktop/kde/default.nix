{ inputs, ... }:

{
  imports = [
    ../common
    inputs.plasma-manager.homeManagerModules.plasma-manager
  ];

  programs.plasma = {
    enable = true;
    shortcuts = {
      "services/systemsettings.desktop"."_launch" = [
        "Meta+I"
        "Tools"
      ];
    };
    configFile = {
      "kcminputrc"."Keyboard"."NumLock" = 0;
      "kded5rc"."Module-printmanager"."autoload" = false;
      "kscreenlockerrc"."Daemon"."Autolock" = false;
      "kscreenlockerrc"."Daemon"."LockOnResume" = false;
      "kwinrc"."Wayland"."InputMethod" =
        "/run/current-system/sw/share/applications/org.fcitx.Fcitx5.desktop";
    };
  };
}
