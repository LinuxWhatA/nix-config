{ lib, ... }:

{
  programs.git = {
    enable = true;
    settings.user = {
      name = "LinuxWhatA";
      mail = lib.mkDefault "5351697+linuxwhata@user.noreply.gitee.com";
    };

    lfs.enable = true;
    ignores = [ ".direnv" ];
  };
}
