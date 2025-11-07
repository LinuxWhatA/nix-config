{ flake, ... }:

{
  programs.git = {
    enable = true;
    ignores = [ "*~" "*.swp" ];
    lfs.enable = true;
    settings.user = {
      name = flake.config.me.fullname;
      mail = flake.config.me.email;
    };
  };
}
