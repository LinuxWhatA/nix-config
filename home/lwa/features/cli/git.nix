{ lib, ... }:

{
  programs.git = {
    enable = true;
    userName = "LinuxWhatA";
    userEmail = lib.mkDefault "linuxwhata@qq.com";

    lfs.enable = true;
    ignores = [
      ".direnv"
      "result"
    ];
  };
}
