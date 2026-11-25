# 动机：.max 缩略图由 max-thumbnail-gen 包安装 share/thumbnailers/max.thumbnailer
#       （on-demand 提取内嵌缩略图给 KDE，KDE 自缓存），但 KDE6 PreviewJob 只请求 dolphinrc
#       [PreviewSettings] Plugins 白名单里的插件（Id=文件名 max），新插件不登记就永远不出图。
# 前提：MIME application/x-wine-extension-max 由 wine-3dsmax install-launcher 写入
#       ~/.local/share/mime（env.sh 禁用了 winemenubuilder，不由 Wine 自己导出）；没跑过
#       install-launcher 时文件管理器认不出 .max，白名单也不会生效。
{ pkgs, ... }:

{
  # 包与模块同生同灭：max-thumbnail-gen 自带 share/thumbnailers/max.thumbnailer，模块自装
  # （与 tracedraw 同法），不进 modules/home/gui/packages.nix 的通用 GUI 列表。
  home.packages = [ pkgs.max-thumbnail-gen ];

  # 与 tracedraw 同法：kread/kwriteconfig6 只改这一个键，不动 Dolphin 其它设置；
  # 激活脚本 PATH 不含 kconfig，必须用绝对路径调用（幂等：已在则跳过）。
  # 切换后必须重启 Dolphin：KIO 在进程内缓存缩略图插件列表，不重启仍用旧列表。
  # $DRY_RUN_CMD 虽被 HM 标记弃用，但仍是当前 dry-run 的唯一开关，保留以维持语义。
  #
  # 关键：Plugins 键缺失时 Dolphin 用 KIO::PreviewJob::defaultPlugins()（全部可用插件，自动包含
  # max），所以只应在用户已有显式白名单时追加；若写成 ",max"，键一旦存在就会顶掉默认列表，
  # 新机器/删掉 dolphinrc 后所有默认预览都会消失。
  home.activation.maxThumbnailerDolphin = ''
    kreadconfig6=${pkgs.kdePackages.kconfig}/bin/kreadconfig6
    kwriteconfig6=${pkgs.kdePackages.kconfig}/bin/kwriteconfig6
    if $kreadconfig6 --file dolphinrc --group PreviewSettings --dump 2>/dev/null | grep -qE '^[[:space:]]*Plugins:'; then
      plugins=$($kreadconfig6 --file dolphinrc --group PreviewSettings --key Plugins 2>/dev/null || true)
      if [ -n "$plugins" ] && ! printf '%s' "$plugins" | tr ',' '\n' | grep -qx max; then
        $DRY_RUN_CMD $kwriteconfig6 --file dolphinrc --group PreviewSettings --key Plugins "''${plugins},max"
      fi
    fi
  '';
}
