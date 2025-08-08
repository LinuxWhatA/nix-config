{ pkgs, ... }:

{
  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub = {
      enable = true;
      efiSupport = true;
      device = "nodev";
      default = "saved";
      splashImage = null;
      gfxmodeEfi = "1024x768";
      configurationLimit = 10;
      theme = "${pkgs.grub-cyberre-theme}/grub/themes/CyberRe";
      extraFiles = {
        "ntloader" = "${pkgs.ntloader}/ntloader";
        "initrd.cpio" = "${pkgs.ntloader}/initrd.cpio";
      };
      extraEntries = ''
        menuentry "Windows VHD" --class windows {
          savedefault
          search -s -f /ntloader
          search -s dev -f /OS/Windows.vhd
          probe -s dev_uuid -u $dev
          if [ "''${grub_platform}" = "efi" ]; then
            linux /ntloader uuid=''${dev_uuid} vhd=/OS/windows.vhd
            initrd /initrd.cpio
          else
            linux16 /ntloader uuid=''${dev_uuid} vhd=/OS/windows.vhd
            initrd16 /initrd.cpio
          fi;
        }

        menuentry "Ventoy" {
          search -s -l VTOYEFI
          chainloader /EFI/BOOT/grubx64_real.efi
        }

        menuentry "Halt" {
          halt
        }
      '';
    };
  };
}
