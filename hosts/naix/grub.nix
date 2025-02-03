{ pkgs, ... }:

{
  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub = {
      enable = true;
      efiSupport = true;
      device = "nodev";
      default = "saved";
      configurationLimit = 10;
      extraConfig = "set timeout=5";
      theme = "${pkgs.grub-cyberre-theme}/grub/themes/CyberRe";
      extraFiles = {
        "ntloader" = "${pkgs.ntloader}/ntloader";
        "initrd.cpio" = "${pkgs.ntloader}/initrd.cpio";
      };
      extraEntries = ''
        menuentry "Windows VHD" --class windows {
          savedefault
          search --no-floppy --efidisk-only --set --file /ntloader
          search --no-floppy --set=fs_uuid --file /OS/Windows.vhd
          probe --set=dev_uuid --fs-uuid $fs_uuid
          chainloader /ntloader initrd=/initrd.cpio uuid=$dev_uuid file=/OS/Windows.vhd
        }

        menuentry "Ventoy" {
          savedefault
          search --no-floppy --efidisk-only --set --label VTOYEFI
          chainloader /EFI/BOOT/grubx64_real.efi
        }
      '';
    };
  };
}
