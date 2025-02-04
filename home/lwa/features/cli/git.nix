{ lib, ... }:

{
  programs.git = {
    enable = true;
    userName = "LinuxWhatA";
    userEmail = lib.mkDefault "5351697+linuxwhata@user.noreply.gitee.com";

    lfs.enable = true;
    ignores = [
      ".direnv"
      "result"
    ];
  };
}
