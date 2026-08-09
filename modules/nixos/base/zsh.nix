{ flake, pkgs, ... }:

{
  programs = {
    zsh.enable = true;
    zsh.promptInit = ''
      [ "$UID" -eq 0 ] && source /home/${flake.config.me.username}/.zshrc
    '';
    starship = {
      enable = true;
      presets = [ "nerd-font-symbols" ];
      settings = {
        add_newline = false;
        git_status.ignore_submodules = true;
      };
    };
  };
  users.defaultUserShell = pkgs.zsh;
}
