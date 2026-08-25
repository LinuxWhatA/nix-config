# zsh 与 starship（HM 负责 shell 文件与插件，session 变量经 hm-session-vars.sh 自动注入）
# 注：users.defaultUserShell 保留在 NixOS 层（系统用户属性）
{ pkgs, lib, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    historySubstringSearch = {
      enable = true;
      searchUpKey = "$terminfo[kcuu1]";
      searchDownKey = "$terminfo[kcud1]";
    };
    setOptions = [
      "HIST_IGNORE_ALL_DUPS"
      "SHARE_HISTORY"
      "HIST_FCNTL_LOCK"
    ];
    # initContent（initExtra 已弃用，见 HM modules/programs/zsh/deprecated.nix）
    initContent = lib.mkOrder 1000 ''
      # Linux TTY / dumb / Windows Terminal 回退纯文本符号预设（直接引用 starship 包内预设，随版本同步）
      # WT_SESSION 为 Windows Terminal 官方环境变量，经 WSLENV 传入 WSL
      if [[ "$TERM" == linux || "$TERM" == dumb || -n "$WT_SESSION" ]]; then
        export STARSHIP_CONFIG=${pkgs.starship}/share/starship/presets/plain-text-symbols.toml
      fi
    '';
  };

  programs.starship = {
    enable = true;
    presets = [ "nerd-font-symbols" ];
    settings = {
      add_newline = false;
      git_status.ignore_submodules = true;
    };
  };
}
