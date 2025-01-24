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
  version = "0.27.8-unstable-2024-12-17";

  src = fetchFromGitHub {
    owner = "UnblockNeteaseMusic";
    repo = "server";
    rev = "b6ed5790037716282dd0b1b956c11614e4426ebe";
    hash = "sha256-jDEigvQgD133nZGwb0SXwRQrBzPjhmifQBd6X0cnutQ=";
  };

  nativeBuildInputs = [
    makeWrapper
    openssl
    nodejs
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib
    cp -r * $out/lib
    makeWrapper "${nodejs}/bin/node" "$out/bin/unblock-netease-music" \
      --prefix PATH : ${lib.makeBinPath [ yt-dlp ]} \
      --add-flags "$out/lib/app.js"

    # CA certificate: $out/lib/ca.crt
    bash $out/lib/generate-cert.sh

    runHook postInstall
  '';

  meta = {
    description = "Revive unavailable songs for Netease Cloud Music (Refactored & Enhanced version) ";
    homepage = "https://github.com/UnblockNeteaseMusic/serverc";
    license = with lib.licenses; [
      gpl3
      lgpl3
    ];
    mainProgram = pname;
    platforms = lib.platforms.linux;
  };
}
