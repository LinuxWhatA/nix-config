{ flake, ... }:

{
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 30d --keep 10";
    flake = "/home/${flake.config.me.username}/nix-config";
  };
}
