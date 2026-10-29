{ pkgs, ... }:

{
  home.packages = with pkgs; [
    vlc # 视频播放器
    nomacs # 图片查看器
    scrcpy # 手机投屏
    wechat
    fsearch # 文件搜索
    rayburst # 下载器
    xunlei-uos
    moonlight-qt # 游戏流媒体
    wpsoffice-cn
    winetricks
    deepin-wine10-stable
    wineWow64Packages.staging
    proton-run
    dwproton-run
    umu-launcher
    dsh-desktop-next
  ];
}
