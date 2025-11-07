{
  pkgs ? import <nixpkgs> { },
}:

pkgs.mkShell {
  packages = with pkgs; [
    libbfd
    libiberty
    libz
    cpio
  ];
}
