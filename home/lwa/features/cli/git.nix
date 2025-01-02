{ lib, ... }:

{
  programs = {
    git = {
      enable = true;
      userName = "LinuxWhatA";
      userEmail = lib.mkDefault "linuxwhata@qq.com";
    };
  };
}
