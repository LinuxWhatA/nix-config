{
  steam-run,
  proton-caller,
  proton-ge-bin,
  writeShellScriptBin,
}:

writeShellScriptBin "proton-call" ''
  [ -f ~/.config/proton.conf ] || cat > ~/.config/proton.conf <<EOF
    data = "/home/lwa/Documents/"
    steam = "/home/lwa/.steam/steam/"
    common = "/home/lwa/.steam/steam/steamapps/common/"
  EOF
  ${steam-run}/bin/steam-run ${proton-caller}/bin/proton-call -c ${proton-ge-bin.steamcompattool} $@
''
