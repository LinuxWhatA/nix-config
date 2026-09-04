{ pkgs, ... }:

{
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      thunar-archive-plugin
      thunar-volman
      thunar-media-tags-plugin # 媒体文件详情、批量重命名、标签编辑
      thunar-shares-plugin # Samba 共享
    ];
  };

  # 核心功能
  services = {
    gvfs.enable = true;
    tumbler.enable = true;
    udisks2.enable = true;
  };

  environment.systemPackages = with pkgs; [
    zip
    unzip
    p7zip
    file-roller
  ];

  xdg.mime.defaultApplications = {
    "inode/directory" = "thunar.desktop";
  };
}
