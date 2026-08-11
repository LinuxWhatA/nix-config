{
  pkgs,
  lib,
  config,
  ...
}:

let
  # TTY 使用纯文本符号预设，图形终端使用 Nerd Font 预设
  ttySettingsFile = (pkgs.formats.toml { }).generate "starship-tty.toml" (
    (lib.importTOML "${pkgs.starship}/share/starship/presets/plain-text-symbols.toml")
    // config.programs.starship.settings
  );
in
{
  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
      setOptions = [
        "HIST_IGNORE_ALL_DUPS"
        "SHARE_HISTORY"
        "HIST_FCNTL_LOCK"
      ];
      interactiveShellInit = ''
        source ${pkgs.zsh-history-substring-search}/share/zsh-history-substring-search/zsh-history-substring-search.zsh
        bindkey "$terminfo[kcuu1]" history-substring-search-up
        bindkey "$terminfo[kcud1]" history-substring-search-down

        # Linux TTY 使用纯文本符号预设
        if [[ "$TERM" == linux ]]; then
          export STARSHIP_CONFIG=${ttySettingsFile}
        fi
      '';
    };
    starship = {
      enable = true;
      presets = [ "nerd-font-symbols" ];
      settings = {
        add_newline = false;
        git_status.ignore_submodules = true;
      };
    };
  };
  users.defaultUserShell = pkgs.zsh;
}
