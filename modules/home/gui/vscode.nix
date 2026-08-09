{
  pkgs,
  flake,
  osConfig,
  ...
}:

let
  mergeJson = (import (flake.inputs.self + /lib/merge-json.nix) { inherit pkgs; }).mergeJson;
in
{
  programs.vscode = {
    enable = true;
    profiles.default.extensions = with pkgs.vscode-extensions; [
      mkhl.direnv
      ms-python.python
      jnoortheen.nix-ide
      ms-python.black-formatter
      ms-ceintl.vscode-language-pack-zh-hans
    ];
  };

  home.activation.vscodeSettings =
    let
      argv = builtins.toJSON {
        "locale" = "zh-cn";
        "password-store" = "basic";
        "enable-crash-reporter" = false;
      };
      userSettings = builtins.toJSON {
        "update.mode" = "none";
        "editor.fontLigatures" = true;
        "window.commandCenter" = false;
        "chat.disableAIFeatures" = true;
        "window.titleBarStyle" = "custom";
        "files.autoGuessEncoding" = true;
        "extensions.autoCheckUpdates" = false;
        "editor.fontFamily" = "'FiraCode Nerd Font Mono'";
        "terminal.integrated.fontFamily" = "'MesloLGS NF'";
        "[nix]" = {
          "editor.tabSize" = 2;
        };
        "nix.serverPath" = "nixd";
        "nix.enableLanguageServer" = true;
        "nix.serverSettings" = {
          nixd = {
            formatting = {
              command = [ "nixfmt" ];
            };
            options = {
              nixos = {
                expr = ''(builtins.getFlake "${flake.inputs.self}").nixosConfigurations.${osConfig.networking.hostName}.options'';
              };
            };
          };
        };
      };
    in
    mergeJson ".vscode/argv.json" argv
    + mergeJson ".config/Code/User/settings.json" userSettings;
}
