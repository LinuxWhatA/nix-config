{
  lib,
  stdenv,
  fetchurl,
  msitools,
  steam-run,
  proton-caller,
  proton-ge-bin,
  writeShellScriptBin,
}:

let
  proton-call = writeShellScriptBin "proton-call" ''
    [ -f ~/.config/proton.conf ] || cat > ~/.config/proton.conf <<EOF
    data = "$HOME/Documents/"
    steam = "$HOME/.steam/steam/"
    EOF
    ${steam-run}/bin/steam-run ${proton-caller}/bin/proton-call -c ${proton-ge-bin.steamcompattool} -r $@
  '';
in
stdenv.mkDerivation {
  pname = "epic-games";
  version = "17.2.0";

  src = ./EpicInstaller-17.2.0.msi;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    ${msitools}/bin/msiextract $src -C $out/epic

    mkdir -p $out/bin
    cat > $out/bin/epic-games-launcher <<EOF
    #!/bin/sh
    ${proton-call}/bin/proton-call '$out/epic/Program Files/Epic Games/Launcher/Portal/Binaries/Win32/EpicGamesLauncher.exe' "$@"
    EOF
    chmod +x $out/bin/epic-games-launcher

    mkdir -p $out/share/applications
    cat > $out/share/applications/epic-games.desktop <<EOF
    [Desktop Entry]
    Name=Epic Launcher
    Comment=Epic Launcher
    Exec=epic-games-launcher %U
    Icon=$out/epic/Program Files/Epic Games/Launcher/Portal/Content/UI/EPICLogo.png
    Terminal=false
    Type=Application
    Categories=Network;FileTransfer;Game;
    PrefersNonDefaultGPU=true
    X-KDE-RunOnDiscreteGpu=true
    EOF

    runHook postInstall
  '';

  meta = {
    description = "Epic Games";
    homepage = "https://www.epicgames.com";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
