{
  steam-run,
  proton-caller,
  proton-ge-bin,
  writeShellScriptBin,
}:

writeShellScriptBin "proton-call" ''
  [ -f ~/.config/proton.conf ] || cat > ~/.config/proton.conf <<EOF
  data = "$HOME/Documents/"
  steam = "$HOME/.steam/steam/"
  common = "$HOME/.steam/steam/steamapps/common/"
  EOF
  ${steam-run}/bin/steam-run ${proton-caller}/bin/proton-call -c ${proton-ge-bin.steamcompattool} $@
''
