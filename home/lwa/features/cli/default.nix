{ pkgs, ... }:

{
  imports = [
    ./zsh
    ./git.nix
    ./direnv.nix
    # (fetchTarball "https://github.com/nix-community/nixos-vscode-server/tarball/master")
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

    winePackages.stagingFull
    winetricks
  ];

  my.services.unblock-netease-music = {
    enable = false;
    env = "SEARCH_ALBUM=true";
  };

  # services.vscode-server.enable = true;
  # services.vscode-server.enableFHS = true;
}
