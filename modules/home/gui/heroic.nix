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

  home.file.".config/heroic/tools/proton/DWProton" = {
    force = true;
    source = "${pkgs.dwproton-bin.steamcompattool}";
  };

  home.activation.heroicSettings = pkgs.mergeJson ".config/heroic/config.json" {
    defaultSettings = {
      checkForUpdatesOnStartup = false;
    };
  };
}
