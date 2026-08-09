{ pkgs, ... }:

let
  # 源码编译的 a1 GRUB（grub-mkimage + x86_64-efi 模块 + builtin.txt + bootmgfw.efi）
  a1ive = pkgs.a1ive-grub;
in
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
      extraConfig = "set enable_progress_indicator=0";
      extraInstallCommands = ''
        # a1 模块与字体（源码编译产物）
        cp -rf ${a1ive}/lib/grub/x86_64-efi /boot/grub/
        mkdir -p /boot/grub/fonts
        cp -f ${a1ive}/share/grub/unicode.pf2 ${a1ive}/share/grub/ascii.pf2 ${a1ive}/share/grub/euro.pf2 /boot/grub/fonts/

        # ntboot --efi 需要 bootmgfw.efi
        cp -f ${a1ive}/bootmgfw.efi /boot/grub/

        # 用源码编译的 grub-mkimage 生成 a1 core image
        ${a1ive}/bin/grub-mkimage -d ${a1ive}/lib/grub/x86_64-efi -p "/grub" -o /boot/grub/grubx64.efi -O x86_64-efi $(cat ${a1ive}/builtin.txt)
        mv -f /boot/grub/grubx64.efi /boot/EFI/NixOS-boot/
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
