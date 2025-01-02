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

  # Dynamic triple buffering
  # You might need to disable aliases to make it work
  # nixpkgs.config.allowAliases = false;
  nixpkgs.overlays = [
    # GNOME 46: triple-buffering-v4-46
    (final: prev: {
      gnome = prev.gnome.overrideScope (
        gnomeFinal: gnomePrev: {
          mutter = gnomePrev.mutter.overrideAttrs (old: {
            src = pkgs.fetchFromGitLab {
              domain = "gitlab.gnome.org";
              owner = "vanvugt";
              repo = "mutter";
              rev = "triple-buffering-v4-46";
              hash = "sha256-C2VfW3ThPEZ37YkX7ejlyumLnWa9oij333d5c4yfZxc=";
            };
          });
        }
      );
    })
  ];

  # Fix broken stuff
  services.avahi.enable = false;
  networking.networkmanager.enable = false;
}
