{
  inputs,
  lib,
  ...
}:

{
  nix = {
    settings = {
      trusted-users = [
        "root"
        "@wheel"
      ];
      auto-optimise-store = lib.mkDefault true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;

      substituters = lib.mkForce [
        "https://mirrors.cernet.edu.cn/nix-channels/store"
      ];
    };

    gc = {
      automatic = true;
      dates = "weekly";
      # Keep the last 3 generations
      options = "--delete-older-than +3";
    };
  };
}
