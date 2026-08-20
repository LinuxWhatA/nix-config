# redmi 的 GRUB 差异项（公共部分见 modules/nixos/hardware/grub.nix）
{ flake, pkgs, ... }:

let
  # 源码编译的 a1 GRUB（grub-mkimage + x86_64-efi 模块 + builtin.txt + bootmgfw.efi）
  a1ive = pkgs.a1ive-grub;
  bin = pkgs.coreutils + "/bin";
in
{
  imports = [ (flake.inputs.self + /modules/nixos/hardware/grub.nix) ];

  boot.loader = {
    timeout = 5;
    grub = {
      extraConfig = "set enable_progress_indicator=0";
      extraInstallCommands = ''
        # 模块与字体（源码编译产物）
        ${bin}/cp -rf ${a1ive}/lib/grub/x86_64-efi /boot/grub/
        ${bin}/mkdir -p /boot/grub/fonts
        ${bin}/cp -f ${a1ive}/share/grub/*.pf2 /boot/grub/fonts/

        # ntboot --efi 需要 bootmgfw.efi
        ${bin}/cp -f ${a1ive}/bootmgfw.efi /boot/grub/

        # core image
        ${bin}/cp -f ${a1ive}/grubx64.efi /boot/EFI/NixOS-boot/
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
