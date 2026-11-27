# Flatpak 沙箱应用运行时（桌面主机通用）。
# 动机：部分图形应用（如 Cordial）依赖完整 GNOME 运行时，其 Vulkan/WebKit/GTK
# 版本经上游实测，比在发行版 FHS 里拼库更可靠——NixOS 无 glibc 兼容层，这类应用
# 走 Flatpak 是官方推荐路径。
#
# 本仓 nixpkgs 的 services.flatpak 仅含 enable/package 两选项（无声明式
# packages/remotes），故 remote 与应用改用开机 oneshot 服务幂等落地。
# 注意：该 unit 由 multi-user.target 拉起，仅在开机运行，nixos-rebuild switch
# 不会触发它——改了安装逻辑需重启或手动 systemctl restart 才生效。
{ config, ... }:

let
  flatpakBin = "${config.services.flatpak.package}/bin/flatpak";
in
{
  services.flatpak.enable = true;

  # 声明式落地 Cordial 官方 Flatpak 远端与应用；--if-not-exists / 非交互保证幂等。
  # 远端经 GitHub Pages 发布、已由上游签名（flatpakrepo 含 GPGKey），故开启校验。
  systemd.services.flatpak-cordial-setup = {
    description = "Add Cordial Flatpak remote and install io.github.luohoa97.Cordial";
    wantedBy = [ "multi-user.target" ];
    after = [
      "flatpak-system-helper.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # 冷安装需从 Flathub 拉取 org.gnome.Platform（约 420 MB），2min 会误杀慢网
      # （10 Mbps 约 6 分钟）。给足 15min 覆盖极慢链路；真"卡死"时 flatpak 自己
      # 会因网络错误退出，此时长只是最后兜底，不会无限拖住开机。
      TimeoutStartSec = "15min";
    };
    script = ''
      # Cordial 官方 remote 只承载应用本体，其依赖的 org.gnome.Platform 50 运行时
      # 托管在 Flathub，故须先补 Flathub 远端并预装运行时，否则 install 报
      # "需要的运行时 ... 未找到"。
      ${flatpakBin} remote-add --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo
      ${flatpakBin} remote-add --if-not-exists cordial \
        https://luohoa97.github.io/cordial/cordial.flatpakrepo
      # --if-not-exists 对已存在的远端是 no-op，不会纠正旧版脚本留下的
      # no-gpg-verify；显式改回校验态，让存量主机每次开机自愈。
      ${flatpakBin} remote-modify --gpg-verify cordial
      ${flatpakBin} install --or-update --assumeyes --noninteractive \
        flathub org.gnome.Platform//50
      ${flatpakBin} install --or-update --assumeyes --noninteractive \
        cordial io.github.luohoa97.Cordial
    '';
  };
}
