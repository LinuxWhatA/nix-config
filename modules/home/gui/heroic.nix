{ pkgs, ... }:

{
  home.packages = with pkgs; [
    (heroic.override {
      extraPkgs = pkgs: [
        pkgs.gamescope
      ];
    })
  ];

  home.file.".config/heroic/tools/proton/Proton-GE" = {
    force = true;
    source = "${pkgs.proton-ge-bin.steamcompattool}";
  };

  home.activation.heroicSettings =
    let
      config = builtins.toJSON {
        defaultSettings = {
          checkForUpdatesOnStartup = false;
        };
      };
    in
    ''
      file="$HOME/.config/heroic/config.json"
      [ -f $file ] || (mkdir -p $(dirname $file) && echo "{}" > $file)
      json=$(${pkgs.fixjson}/bin/fixjson --minify $file)
      echo $json '${config}' | ${pkgs.jq}/bin/jq -s add > $file
    '';
}
