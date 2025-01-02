{ pkgs, ... }:

{
  environment.shells = [ pkgs.zsh ];
  users.defaultUserShell = pkgs.zsh;
  system.userActivationScripts.zshrc = "touch .zshrc";

  programs.zsh = {
    enable = true;
    histSize = 10000;
    enableCompletion = false;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;

    setOptions = [ "HIST_IGNORE_ALL_DUPS" ];

    ohMyZsh = {
      enable = true;
      plugins = [
        "history-substring-search"
        "powerlevel10k-config"
      ];
      theme = "powerlevel10k";
      custom = "${(pkgs.callPackage ./oh-my-zsh-custom.nix { })}";
    };

    shellAliases = {
      ll = "ls -lth";
      la = "ls -lath";
      gc1 = "sudo nix-env --delete-generations +1 --profile";
      gc = "gc1 /nix/var/nix/profiles/system && gc1 ~/.local/state/nix/profiles/home-manager && sudo nix-store --gc";
    };
  };
}
