{ flake, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    file
    tree
    lsof
    wget
    net-tools
  ];

  programs = {
    zsh.enable = true;
    zsh.promptInit = ''
      [ "$UID" -eq 0 ] && source /home/${flake.config.me.username}/.zshrc
    '';
    adb.enable = true;
    appimage.enable = true;
    appimage.binfmt = true;
    zoxide.enable = true;
    starship = {
      enable = true;
      presets = [ "nerd-font-symbols" ];
    };
  };
  users.defaultUserShell = pkgs.zsh;

  users.users.${flake.config.me.username}.extraGroups = [ "adbusers" ];

  # 允许 Electron 在 Wayland 原生上运行
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };
}
