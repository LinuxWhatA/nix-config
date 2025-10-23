{ pkgs, ... }:

{
  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.autoSuspend = false;
  services.gnome.games.enable = false;

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

  environment.variables = {
    XMODIFIERS = "@im=fcitx";
    QT_IM_MODULE = "fcitx";
  };

  networking.firewall = rec {
    allowedTCPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
    allowedUDPPortRanges = allowedTCPPortRanges;
  };
}
