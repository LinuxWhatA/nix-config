{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-extensions; [
      mkhl.direnv
      ms-python.python
      jnoortheen.nix-ide
      ms-python.black-formatter
      ms-ceintl.vscode-language-pack-zh-hans
    ];
  };

  home.activation.modifyArgv =
    let
      argv = builtins.toJSON {
        "locale" = "zh-cn";
        "password-store" = "basic";
        "enable-crash-reporter" = false;
      };
      userSettings = builtins.toJSON {
        "update.mode" = "none";
        "extensions.autoCheckUpdates" = false;
        "[nix]" = {
          "editor.tabSize" = 2;
          "editor.defaultFormatter" = "jnoortheen.nix-ide";
        };
        "editor.fontLigatures" = true;
        "window.commandCenter" = false;
        "window.titleBarStyle" = "custom";
        "editor.fontFamily" = "'FiraCode Nerd Font Mono'";
        "terminal.integrated.fontFamily" = "'MesloLGS NF'";
        "nix.serverPath" = "nixd";
        "nix.enableLanguageServer" = true;
      };
    in
    ''
      file="$HOME/.vscode/argv.json"
      [ -f $file ] || (mkdir -p $(dirname $file) && echo "{}" > $file)
      json=$(${pkgs.fixjson}/bin/fixjson --minify $file)
      echo $json '${argv}' | ${pkgs.jq}/bin/jq -s add > $file

      file="$HOME/.config/Code/User/settings.json"
      [ -f $file ] || (mkdir -p $(dirname $file) && echo "{}" > $file)
      json=$(${pkgs.fixjson}/bin/fixjson --minify $file)
      echo $json '${userSettings}' | ${pkgs.jq}/bin/jq -s add > $file
    '';
}
