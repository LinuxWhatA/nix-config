{ pkgs, ... }:

{
  home = {
    packages = with pkgs; [
      (heroic.override {
        extraPkgs = pkgs: [
          pkgs.gamescope
        ];
      })
    ];

    file.".config/heroic/tools/proton/Proton-GE" = {
      force = true;
      source = "${pkgs.proton-ge-bin.steamcompattool}";
    };

    file.".config/heroic/tools/proton/DWProton" = {
      force = true;
      source = "${pkgs.dwproton-bin.steamcompattool}";
    };

    activation.heroicSettings = pkgs.mergeJson ".config/heroic/config.json" {
      defaultSettings = {
        checkForUpdatesOnStartup = false;
      };
    };
  };
}
