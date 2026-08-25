{ flake, pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    promptInit = ''
      [ "$UID" -eq 0 ] && source /home/${flake.config.me.username}/.zshrc
    '';
  };
  users.defaultUserShell = pkgs.zsh;
  users.users.root.shell = pkgs.zsh;
}
