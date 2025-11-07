{ pkgs, ... }:

{
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      meslo-lgs-nf
      dejavu_fonts
      nerd-fonts.fira-code
      winfonts
    ];

    fontconfig.defaultFonts = {
      serif = [
        "DejaVu Serif"
        "Microsoft YaHei"
      ];
      sansSerif = [
        "DejaVu Sans"
        "Microsoft YaHei"
      ];
      monospace = [
        "DejaVu Sans Mono"
        "FiraCode Nerd Font Mono"
      ];
    };
  };
}
