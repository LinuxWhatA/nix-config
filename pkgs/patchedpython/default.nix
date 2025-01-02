{
  lib,
  python3,
  pkgs ? import <nixpkgs> { },
}:

let
  # We currently take all libraries from systemd and nix as the default
  # https://github.com/NixOS/nixpkgs/blob/c339c066b893e5683830ba870b1ccd3bbea88ece/nixos/modules/programs/nix-ld.nix#L44
  pythonldlibpath = lib.makeLibraryPath (
    with pkgs;
    [
      zlib
      zstd
      stdenv.cc.cc
      curl
      openssl
      attr
      libssh
      bzip2
      libxml2
      acl
      libsodium
      util-linux
      xz
      systemd
    ]
  );
  # Darwin requires a different library path prefix
  wrapPrefix = if (!pkgs.stdenv.isDarwin) then "LD_LIBRARY_PATH" else "DYLD_LIBRARY_PATH";

  pip = pkgs.writeShellScriptBin "pip" ''
    [ -f ~/.venv/bin/pip ] || python3 -m venv ~/.venv --copies
    ~/.venv/bin/pip config set global.index-url https://mirrors.cernet.edu.cn/pypi/web/simple
    ~/.venv/bin/pip $@
  '';
in

pkgs.symlinkJoin {
  name = "python";
  paths = [
    python3
    pip
  ];
  buildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    wrapProgram "$out/bin/python3" --prefix ${wrapPrefix} : "${pythonldlibpath}"
  '';
}
