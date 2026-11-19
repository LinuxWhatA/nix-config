{ pkgs, ... }:

{
  home.packages = [ pkgs.nomacs ];

  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications = {
    # nomacs 桌面文件是 org.nomacs.ImageLounge.desktop
    "image/avif" = [ "org.nomacs.ImageLounge.desktop" ];
    "image/bmp" = [ "org.nomacs.ImageLounge.desktop" ];
    "image/gif" = [ "org.nomacs.ImageLounge.desktop" ];
    "image/heic" = [ "org.nomacs.ImageLounge.desktop" ];
    "image/heif" = [ "org.nomacs.ImageLounge.desktop" ];
    "image/jpeg" = [ "org.nomacs.ImageLounge.desktop" ];
    "image/jxl" = [ "org.nomacs.ImageLounge.desktop" ];
    "image/png" = [ "org.nomacs.ImageLounge.desktop" ];
    "image/tiff" = [ "org.nomacs.ImageLounge.desktop" ];
    "image/webp" = [ "org.nomacs.ImageLounge.desktop" ];
    "image/x-eps" = [ "org.nomacs.ImageLounge.desktop" ];
    "image/x-ico" = [ "org.nomacs.ImageLounge.desktop" ];
    "image/x-portable-bitmap" = [ "org.nomacs.ImageLounge.desktop" ];
    "image/x-portable-graymap" = [ "org.nomacs.ImageLounge.desktop" ];
    "image/x-portable-pixmap" = [ "org.nomacs.ImageLounge.desktop" ];
    "image/x-xbitmap" = [ "org.nomacs.ImageLounge.desktop" ];
    "image/x-xpixmap" = [ "org.nomacs.ImageLounge.desktop" ];
  };
}
