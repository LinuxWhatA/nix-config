{
  lib,
  fetchFromGitHub,
  stdenv,
  makeWrapper,
  nodejs,
  openssl,
  yt-dlp,
}:

stdenv.mkDerivation rec {
  pname = "unblock-netease-music";
  version = "0.28.0";

  src = fetchFromGitHub {
    owner = "UnblockNeteaseMusic";
    repo = "server";
    rev = "v${version}";
    hash = "sha256-OqwsQ3kPlC/cjNOBXIiIV5rD3luHnJ4kLCqwTd2xhoA=";
  };

  nativeBuildInputs = [
    makeWrapper
    openssl
    nodejs
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib}
    cp -r * $out/lib
    makeWrapper "${nodejs}/bin/node" "$out/bin/unblock-netease-music" \
      --prefix PATH : ${lib.makeBinPath [ yt-dlp ]} \
      --add-flags "$out/lib/app.js"

    # CA certificate: $out/lib/ca.crt
    cd $out/lib
    bash $out/lib/generate-cert.sh

    runHook postInstall
  '';

  meta = {
    description = "Revive unavailable songs for Netease Cloud Music (Refactored & Enhanced version) ";
    homepage = "https://github.com/UnblockNeteaseMusic/server";
    license = with lib.licenses; [
      gpl3
      lgpl3
    ];
    mainProgram = pname;
    platforms = lib.platforms.linux;
  };
}
