{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage rec {
  pname = "proton-caller";
  version = "3.1.2";

  src = fetchFromGitHub {
    owner = "LinuxWhatA";
    repo = pname;
    rev = "7ed1962baf920893368f805dc63c896a2f206176";
    sha256 = "sha256-gAnsP4AR1NnTCThF29H3qvI+PP459qYX72+OBHX0kV4=";
  };

  cargoHash = "sha256-LBXCcFqqscCGgtTzt/gr7Lz0ExT9kAWrXPuPuKzKt0E=";

  meta = with lib; {
    description = "Run Windows programs with Proton";
    changelog = "https://github.com/LinuxWhatA/proton-caller/releases/tag/${version}";
    homepage = "https://github.com/LinuxWhatA/proton-caller";
    license = licenses.mit;
    mainProgram = "proton-call";
  };
}
