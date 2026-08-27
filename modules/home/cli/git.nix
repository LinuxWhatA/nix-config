# Git 配置
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
      email = flake.config.me.email;
    };
  };
}
