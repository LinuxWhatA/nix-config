{
  lib,
  config,
  ...
}:

{
  home = {
    username = lib.mkDefault "root";
    homeDirectory = lib.mkDefault "/root";
    stateVersion = lib.mkDefault "25.11";

    file = {
      ".zsh" = {
        force = true;
        source = config.lib.file.mkOutOfStoreSymlink "/home/lwa/.zsh";
      };

      ".zshrc" = {
        force = true;
        source = config.lib.file.mkOutOfStoreSymlink "/home/lwa/.zshrc";
      };

      ".zsh_history" = {
        force = true;
        source = config.lib.file.mkOutOfStoreSymlink "/home/lwa/.zsh_history";
      };
    };
  };
}
