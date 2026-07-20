{ pkgs, ... }:

{
  boot.loader = {
    timeout = 5;
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
      extraInstallCommands = ''
        cp -rf ${pkgs.a1ive-grub}/* /boot/grub
        mv /boot/grub/grubx64.efi /boot/EFI/NixOS-boot/
      '';
      extraEntries = ''
        menuentry "Windows VHD" --class windows {
          savedefault
          search -s -f /OS/Windows.vhd
          ntboot --vhd --efi="''${prefix}/bootmgfw.efi" "/OS/Windows.vhd";
        }

        menuentry "WePE" --class windows {
          search -s -f /OS/WePE_64_V2.3.iso
          map -f /OS/WePE_64_V2.3.iso;
        }

        menuentry "Reboot (R)" --hotkey "r" {
            reboot;
        }

        menuentry "Halt (H)" --hotkey "h" {
            halt;
        }
      '';
    };
  };
}
