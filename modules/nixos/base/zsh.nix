{
  pkgs,
  ...
}:

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

        # Linux TTY / dumb / Windows Terminal 回退纯文本符号预设（直接引用 starship 包内预设，随版本同步）
        # WT_SESSION 为 Windows Terminal 官方环境变量，经 WSLENV 传入 WSL
        if [[ "$TERM" == linux || "$TERM" == dumb || -n "$WT_SESSION" ]]; then
          export STARSHIP_CONFIG=${pkgs.starship}/share/starship/presets/plain-text-symbols.toml
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
