# 动机：tracedraw 是用户级 GUI 应用（Dolphin 里 .cdr 缩略图 + 双击打开），随 home-manager 装用户
#       profile（~/.nix-profile），不进系统 environment.systemPackages；包内 share/thumbnailers 与
#       share/applications 经 XDG_DATA_DIRS 对 KDE 可见。
# 取舍：双击 .cdr 经 home-manager 的 xdg.mimeApps 写 ~/.config/mimeapps.list（用户级，优先于系统
#       /etc/xdg/mimeapps.list，故不占系统层）。
{ pkgs, ... }:

{
  home.packages = [ pkgs.tracedraw ];

  # mimeApps 模块默认 enable=false，只设 defaultApplications 不会生成 ~/.config/mimeapps.list；
  # 显式打开，下面这些关联才真正写入。
  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications = {
    # .cdr 的真实 MIME 是 application/vnd.corel-draw；desktop 的 canonical 由包内 desktop-file-edit
    # 补齐（上游只写 application/x-cdr 历史别名），见 packages/tracedraw
    "application/vnd.corel-draw" = [ "tracedraw.desktop" ];
  };

  # KDE6 的缩略图机制（FilePreviewJob）原生支持 freedesktop .thumbnailer，插件 Id 就是文件名
  # （tracedraw.thumbnailer → "tracedraw"）；但 PreviewJob 只请求 enabledPluginIds 白名单里的插件，
  # 白名单来自 Dolphin 的 ~/.config/dolphinrc [PreviewSettings] Plugins，新装插件不在其中就不会出图。
  # 故激活时把它追加进去（幂等：已在则跳过）。用 kread/kwriteconfig6 只改这一个键，不动 Dolphin 其它
  # 设置；注意激活脚本 PATH 只含 coreutils/grep 等，不含 kconfig，必须用绝对路径调用。
  #
  # 只在用户已有显式白名单时追加：键缺失时 Dolphin 用 KIO::PreviewJob::defaultPlugins()（全部可用
  # 插件，自动包含 tracedraw），写成 ",tracedraw" 会让键存在并顶掉默认列表，反而禁用其它预览。
  home.activation.tracedrawDolphinThumbnailer = ''
    kreadconfig6=${pkgs.kdePackages.kconfig}/bin/kreadconfig6
    kwriteconfig6=${pkgs.kdePackages.kconfig}/bin/kwriteconfig6
    if $kreadconfig6 --file dolphinrc --group PreviewSettings --dump 2>/dev/null | grep -qE '^[[:space:]]*Plugins:'; then
      plugins=$($kreadconfig6 --file dolphinrc --group PreviewSettings --key Plugins 2>/dev/null || true)
      if [ -n "$plugins" ] && ! printf '%s' "$plugins" | tr ',' '\n' | grep -qx tracedraw; then
        $DRY_RUN_CMD $kwriteconfig6 --file dolphinrc --group PreviewSettings --key Plugins "''${plugins},tracedraw"
      fi
    fi
  '';
}
