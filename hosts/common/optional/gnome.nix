{ pkgs, ... }:

{
  services = {
    xserver = {
      desktopManager.gnome = {
        enable = true;
      };
      displayManager.gdm = {
        enable = true;
        autoSuspend = false;
      };
    };
    gnome.games.enable = false;
  };

  environment.gnome.excludePackages = with pkgs; [
    orca # 屏幕阅读器
    yelp # 帮助
    geary # 邮件
    evince # 文档查看器
    epiphany # 浏览器
    simple-scan # 打印
    gnome-tour # 导览
    gnome-maps # 地图
    gnome-music # 音乐
    gnome-weather # 天气
    gnome-contacts # 联系人
  ];

  # Fix broken stuff
  services.avahi.enable = false;
  networking.networkmanager.enable = false;
}
