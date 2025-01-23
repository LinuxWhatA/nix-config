{ config, pkgs, ... }:

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
    source = config.lib.file.mkOutOfStoreSymlink "${pkgs.proton-ge-bin.steamcompattool}";
  };
}
