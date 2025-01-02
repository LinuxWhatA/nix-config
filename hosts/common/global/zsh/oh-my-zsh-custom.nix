{ stdenvNoCC, zsh-powerlevel10k }:

stdenvNoCC.mkDerivation rec {
  name = "oh-my-zsh-custom";
  phases = [ "installPhase" ];
  installPhase = ''
    mkdir -p $out/themes $out/plugins/powerlevel10k-config
    cp -r ${zsh-powerlevel10k}/share/zsh-powerlevel10k/* $out/themes
    cp ${./p10k.zsh} $out/plugins/powerlevel10k-config/powerlevel10k-config.plugin.zsh
  '';
}
