# Git 配置 ——原 modules/home/cli/git.nix
{ flake, ... }:

{
  programs.git = {
    enable = true;
    ignores = [
      "*~"
      "*.swp"
    ];
    settings.user = {
      name = flake.config.me.fullname;
      mail = flake.config.me.email;
    };
  };
}
