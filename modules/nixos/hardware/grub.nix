# GRUB 公共配置（naix/redmi 共用，差异项在各主机 grub.nix）
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
    };
  };
}
