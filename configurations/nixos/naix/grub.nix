# naix 的 GRUB 差异项
{ flake, pkgs, ... }:

{
  imports = [ flake.config.nixosModules.hardware.grub ];

  boot.loader.grub = {
    extraFiles = {
      "ntloader" = "${pkgs.ntloader}/ntloader";
      "initrd.cpio" = "${pkgs.ntloader}/initrd.cpio";
    };
    extraEntries = ''
      menuentry "Windows VHD" --class windows {
        savedefault
        search --no-floppy -s -f /ntloader
        search --no-floppy -s dev -f /OS/Windows.vhd
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
}
