{ pkgs, inputs, ... }:

{
  imports = [
    ./zsh
    ./git.nix
    ./direnv.nix
    inputs.vscode-server.homeModules.default
  ];

  home.packages = with pkgs; [
    fhs
    rar
    yazi
    nixd
    htop
    usbutils
    fastfetch
    proton-run
    vulkan-tools
    patchedpython
    nixfmt-rfc-style

    (wineWowPackages.full.override {
      wineRelease = "staging";
      mingwSupport = true;
    })
    winetricks
  ];

  my.services.unblock-netease-music = {
    enable = true;
    env = "SEARCH_ALBUM=true";
  };

  services.vscode-server.enable = true;
  services.vscode-server.enableFHS = true;
}
