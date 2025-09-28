{
  steam-run,
  proton-ge-bin,
  rustPlatform,
  fetchFromGitHub,
  writeShellScriptBin,
}:

let
  proton-caller = rustPlatform.buildRustPackage {
    pname = "proton-caller";
    version = "3.1.2";
    src = fetchFromGitHub {
      owner = "LinuxWhatA";
      repo = "proton-caller";
      rev = "7ed1962baf920893368f805dc63c896a2f206176";
      sha256 = "sha256-gAnsP4AR1NnTCThF29H3qvI+PP459qYX72+OBHX0kV4=";
    };
    cargoHash = "sha256-AZp6Mbm9Fg+EVr31oJe6/Z8LIwapYhos8JpZzPMiwz0";
    meta.mainProgram = "proton-call";
  };
in
writeShellScriptBin "proton-run" ''
  [ -f ~/.config/proton.conf ] || cat > ~/.config/proton.conf <<EOF
  data = "$HOME/Documents/"
  steam = "$HOME/.steam/steam/"
  common = "$HOME/.steam/steam/steamapps/common/"
  EOF
  exec ${steam-run}/bin/steam-run ${proton-caller}/bin/proton-call -c ${proton-ge-bin.steamcompattool} -r "$@"
''
