{ flake, ... }:

{
  programs.git = {
    enable = true;
    ignores = [ "*~" "*.swp" ];
    settings.user = {
      name = flake.config.me.fullname;
      mail = flake.config.me.email;
    };
  };
}
