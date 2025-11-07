{
  pkgs ? import <nixpkgs> { },
}:

pkgs.mkShell {
  packages = with pkgs; [
    go
    gopls
    go-tools
    gcc
    glibc
    stdenv
  ];
  shellHook = ''
    go env -w CGO_ENABLED=1
    go env -w GO111MODULE=on
    go env -w GOPROXY=https://goproxy.cn,direct
  '';
}
