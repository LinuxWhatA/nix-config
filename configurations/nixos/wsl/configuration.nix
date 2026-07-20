{ ... }:

{
  wsl = {
    enable = true;
    defaultUser = "lwa";
    interop.register = true; # 解决 binfmt 冲突
    wslConf.interop = {
      enabled = true; # 启用互操作功能
      appendWindowsPath = false; # 不附加Windows PATH以提升速度
    };
  };

  programs.nh.enable = true;
  programs.git.enable = true;
  programs.zsh.promptInit = "cd";

  users.mutableUsers = true;

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "wsl";
  system.stateVersion = "25.05";
}
