{
  lib,
  pkgs,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "a1ive-grub";
  version = "2.0.6";

  src = ./grub;

  buildPhase = ''
    modules=$(cat arch/x64/builtin.txt)
    ${pkgs.grub2}/bin/grub-mkimage -d x86_64-efi -p "/grub" -o grubx64.efi -O x86_64-efi $modules
  '';

  installPhase = ''
    mkdir -p $out
    cp -r * $out
    rm -rf $out/arch
  '';

  meta = {
    description = "Fork of GRUB 2 to add various features.";
    homepage = "https://github.com/a1ive/grub";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };
}
