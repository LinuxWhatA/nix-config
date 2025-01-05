{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-extensions; [
      mkhl.direnv
      bbenoist.nix
      ms-python.python
      brettm12345.nixfmt-vscode
      ms-python.black-formatter
      ms-ceintl.vscode-language-pack-zh-hans
    ];
    userSettings = {
      "update.mode" = "none";
      "extensions.autoCheckUpdates" = false;
      "[nix]"."editor.tabSize" = 2;
      "editor.fontLigatures" = true;
      "window.commandCenter" = false;
      "window.titleBarStyle" = "custom";
      "editor.fontFamily" = "'FiraCode Nerd Font Mono'";
      "terminal.integrated.fontFamily" = "'MesloLGS NF'";
    };
  };

  home.activation.modifyArgv =
    let
      argv = builtins.toJSON {
        "locale" = "zh-cn";
        "password-store" = "basic";
        "enable-crash-reporter" = false;
      };
    in
    ''
      file="$HOME/.vscode/argv.json"
      [ -f $file ] || (mkdir -p $(dirname $file) && echo "{}" > $file)
      json=$(${pkgs.fixjson}/bin/fixjson --minify $file)
      echo $json '${argv}' | ${pkgs.jq}/bin/jq -s ".[0]*.[1]" > $file
    '';
}
